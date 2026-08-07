import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/storage/token_storage.dart';
import '../auth/presentation/cubit/auth_cubit.dart';
import '../auth/presentation/cubit/auth_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Main entrance timeline (3 s)
  late final AnimationController _mainCtrl;
  // Orb breathing (loops)
  late final AnimationController _orbCtrl;

  // ── Derived animations ──────────────────────────────────────────────────

  // Glowing orbs
  late final Animation<double> _orbFadeIn;
  late final Animation<double> _orbPulse;

  // Glass card
  late final Animation<double> _cardScale;
  late final Animation<double> _cardFade;

  // Logo inside card
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;

  // App name + tagline
  late final Animation<double> _nameFade;
  late final Animation<Offset> _nameSlide;

  // Bottom progress bar
  late final Animation<double> _progress;

  // Whole screen exit fade
  late final Animation<double> _exitFade;

  @override
  void initState() {
    super.initState();

    _mainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    _orbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    // Orbs
    _orbFadeIn = _curved(0.00, 0.25, Curves.easeOut);
    _orbPulse = Tween(begin: 0.88, end: 1.12).animate(
      CurvedAnimation(parent: _orbCtrl, curve: Curves.easeInOut),
    );

    // Glass card  — elastic pop-in
    _cardScale = Tween(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.10, 0.52, curve: Curves.elasticOut),
      ),
    );
    _cardFade = _curved(0.10, 0.32, Curves.easeOut);

    // Logo
    _logoScale = Tween(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.20, 0.58, curve: Curves.elasticOut),
      ),
    );
    _logoFade = _curved(0.20, 0.42, Curves.easeOut);

    // App name
    _nameFade = _curved(0.48, 0.72, Curves.easeOut);
    _nameSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.48, 0.72, curve: Curves.easeOut),
      ),
    );

    // Progress bar
    _progress = _curved(0.54, 0.97, Curves.easeInOut);

    // Exit fade (last 8 % of timeline)
    _exitFade = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.92, 1.0, curve: Curves.easeIn),
      ),
    );

    // Start auth check in parallel with the splash animation.
    // We capture the result in a Future so we can await it alongside
    // the animation without relying on polling the cubit state —
    // which could race past AuthInitial before the while-loop even starts
    // (the case for first-time users with no stored token).
    final authCubit = context.read<AuthCubit>();
    final authFuture = Future.microtask(
      () => authCubit.checkAuthStatus(),
    );

    // Defer starting the animation and waiting until after the first frame has rendered.
    // This prevents the animation from finishing instantly during engine warmup/cold start.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future.wait<void>([
        _mainCtrl.forward(),
        authFuture,
        Future<void>.delayed(const Duration(milliseconds: 3000)),
      ]).then((_) async {
        if (!mounted) return;

        // Extra safety: if auth somehow still hasn't settled, poll briefly.
        final cubit = context.read<AuthCubit>();
        while (cubit.state is AuthInitial || cubit.state is AuthLoading) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (!mounted) return;
        }
        if (!mounted) return;

        // Mark splash as completed
        hasSplashed = true;

        final state = cubit.state;
        // Consume and immediately clear the pending path so it can't be
        // replayed if the app somehow re-enters this code path.
        final target = targetPathAfterSplash;
        targetPathAfterSplash = null;

        if (state is AuthAuthenticated) {
          final user = state.user;
          if (target != null &&
              target != AppRoutes.splash &&
              target != AppRoutes.onboarding &&
              target != AppRoutes.login &&
              target != AppRoutes.signUp) {
            context.go(target);
          } else {
            if (user.role == 'driver') {
              context.go(AppRoutes.driverDashboard);
            } else {
              context.go(AppRoutes.home);
            }
          }
        } else {
          // Not authenticated — only follow the pending path if it's a public route.
          final publicRoutes = [
            AppRoutes.onboarding,
            AppRoutes.login,
            AppRoutes.signUp,
            AppRoutes.otpVerification,
            AppRoutes.acceptInvite,
          ];
          if (target != null && publicRoutes.any((route) => target.startsWith(route))) {
            context.go(target);
          } else {
            final hasSeen = await TokenStorage().hasSeenOnboarding();
            if (!mounted) return;
            if (hasSeen) {
              context.go(AppRoutes.login);
            } else {
              context.go(AppRoutes.onboarding);
            }
          }
        }
      });
    });
  }

  Animation<double> _curved(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _mainCtrl,
        curve: Interval(begin, end, curve: curve),
      );

  @override
  void dispose() {
    _mainCtrl.dispose();
    _orbCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF080F1E)
          : AppColors.lightBackground,
      body: AnimatedBuilder(
        animation: Listenable.merge([_mainCtrl, _orbCtrl]),
        builder: (context, _) {
          return FadeTransition(
            opacity: _exitFade,
            child: Stack(
              children: [
                // ── Background gradient ─────────────────────────────────
                _Background(isDark: isDark),

                // ── Orb 1 — top-left, primary blue ─────────────────────
                _Orb(
                  top: -size.width * 0.18,
                  left: -size.width * 0.14,
                  diameter: size.width * 0.72,
                  color: AppColors.primary,
                  opacity: _orbFadeIn.value * 0.38,
                  scale: _orbPulse.value,
                ),

                // ── Orb 2 — bottom-right, secondary orange ──────────────
                _Orb(
                  bottom: -size.width * 0.14,
                  right: -size.width * 0.10,
                  diameter: size.width * 0.65,
                  color: AppColors.secondary,
                  opacity: _orbFadeIn.value * 0.30,
                  // counter-phase
                  scale: 1.0 + (1.12 - _orbPulse.value),
                ),

                // ── Orb 3 — mid-right, accent ───────────────────────────
                _Orb(
                  top: size.height * 0.28,
                  right: -size.width * 0.12,
                  diameter: size.width * 0.48,
                  color: AppColors.primaryLight,
                  opacity: _orbFadeIn.value * 0.20,
                  scale: _orbPulse.value * 0.92,
                ),

                // ── Centre content ──────────────────────────────────────
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Glass card + logo
                      FadeTransition(
                        opacity: _cardFade,
                        child: Transform.scale(
                          scale: _cardScale.value,
                          child: _GlassCard(
                            child: FadeTransition(
                              opacity: _logoFade,
                              child: Transform.scale(
                                scale: _logoScale.value,
                                child: Image.asset(
                                  'assets/images/VIPGo.png',
                                  width: 108,
                                  height: 108,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 36),

                      // App name + tagline
                      FadeTransition(
                        opacity: _nameFade,
                        child: SlideTransition(
                          position: _nameSlide,
                          child: Column(
                            children: [
                              Text(
                                'VIPGo',
                                style: GoogleFonts.outfit(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.lightOnSurface,
                                  letterSpacing: 1.8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'YOUR JOURNEY, SIMPLIFIED',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w300,
                                  color: isDark
                                      ? Colors.white.withValues(alpha:0.50)
                                      : AppColors.lightOnSurfaceVariant,
                                  letterSpacing: 3.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Bottom progress bar ─────────────────────────────────
                Positioned(
                  bottom: 56,
                  left: 48,
                  right: 48,
                  child: Opacity(
                    opacity: (_progress.value * 3).clamp(0.0, 1.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: LinearProgressIndicator(
                        value: _progress.value,
                        minHeight: 2.5,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha:0.10)
                            : AppColors.lightOutline,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color.lerp(
                            AppColors.primary,
                            AppColors.secondary,
                            _progress.value,
                          )!,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Background extends StatelessWidget {
  final bool isDark;
  const _Background({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF0B1530),
                  Color(0xFF080F1E),
                  Color(0xFF12082E),
                ]
              : const [
                  Color(0xFFEDF2FF),
                  AppColors.lightBackground,
                  Color(0xFFF0F4FF),
                ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final double? top;
  final double? bottom;
  final double? left;
  final double? right;
  final double diameter;
  final Color color;
  final double opacity;
  final double scale;

  const _Orb({
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.diameter,
    required this.color,
    required this.opacity,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha:opacity),
                color.withValues(alpha:0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(36),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: 176,
          height: 176,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withValues(alpha:0.18),
                      Colors.white.withValues(alpha:0.05),
                    ]
                  : [
                      Colors.white.withValues(alpha:0.72),
                      Colors.white.withValues(alpha:0.40),
                    ],
            ),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha:0.22)
                  : AppColors.primary.withValues(alpha:0.20),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha:isDark ? 0.35 : 0.15),
                blurRadius: 48,
                spreadRadius: -8,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha:isDark ? 0.25 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}
