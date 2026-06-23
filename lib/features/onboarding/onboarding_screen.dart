import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/storage/token_storage.dart';

// ── Page data ─────────────────────────────────────────────────────────────────

class _PageData {
  final String tag;
  final String title;
  final String subtitle;
  final Color accent;
  final String imageUrl;

  const _PageData({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.imageUrl,
  });
}

// Unsplash HD images — specific photo IDs relevant to bus travel / ticketing
const _kPages = [
  _PageData(
    tag: 'PLAN',
    title: 'Plan Your Journey and Find Your Perfect Bus',
    subtitle:
        'Get real-time bus schedules, live route maps, and arrival estimates — all in one place.',
    accent: AppColors.primary,
    imageUrl:
        'assets/images/travel.jpg',
  ),
  _PageData(
    tag: 'BOOK',
    title: 'Book in Seconds',
    subtitle:
        'Purchase your ticket instantly from your phone — no queues, no cash, no stress.',
    accent: AppColors.secondary,
    imageUrl:
        'assets/images/book.jpg',
  ),
  _PageData(
    tag: 'RIDE',
    title: 'Ride with Ease',
    subtitle:
        'Show your digital ticket, board your bus, and enjoy a smooth, comfortable journey.',
    accent: AppColors.success,
    imageUrl:
        'assets/images/ride.jpg',
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _page = 0;
  double _scrollOffset = 0; // raw fractional page value for parallax

  // Drives image + text entrance animations
  late final AnimationController _enterCtrl;
  late final Animation<double> _imageScale;
  late final Animation<double> _imageFade;
  late final Animation<double> _tagFade;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subtitleFade;
  late final Animation<Offset> _subtitleSlide;

  @override
  void initState() {
    super.initState();

    _pageCtrl.addListener(() {
      if (mounted) setState(() => _scrollOffset = _pageCtrl.page ?? 0);
    });

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Image: scale + fade
    _imageScale = Tween(begin: 0.86, end: 1.0).animate(
      CurvedAnimation(
        parent: _enterCtrl,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
      ),
    );
    _imageFade = CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );

    // Tag label — earliest
    _tagFade = CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.25, 0.55, curve: Curves.easeOut),
    );

    // Title — mid
    _titleFade = CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.35, 0.65, curve: Curves.easeOutCubic),
    ));

    // Subtitle — last
    _subtitleFade = CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.50, 0.80, curve: Curves.easeOut),
    );
    _subtitleSlide =
        Tween<Offset>(begin: const Offset(0, 0.30), end: Offset.zero)
            .animate(CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.50, 0.80, curve: Curves.easeOutCubic),
    ));

    _enterCtrl.forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) {
    setState(() => _page = i);
    _enterCtrl.forward(from: 0);
  }

  void _next() async {
    if (_page < _kPages.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 460),
        curve: Curves.easeInOutCubic,
      );
    } else {
      await TokenStorage().setHasSeenOnboarding();
      if (mounted) {
        context.go(AppRoutes.login);
      }
    }
  }

  void _skip() async {
    await TokenStorage().setHasSeenOnboarding();
    if (mounted) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLast = _page == _kPages.length - 1;
    final accent = _kPages[_page].accent;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _enterCtrl,
          builder: (context, _) {
            return Column(
              children: [
                // ── Top row: counter + skip ─────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_page + 1} of ${_kPages.length}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      if (!isLast)
                        TextButton(
                          onPressed: _skip,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                          ),
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 72),
                    ],
                  ),
                ),

                // ── Image PageView ──────────────────────────────────────
                Expanded(
                  flex: 10,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: PageView.builder(
                        controller: _pageCtrl,
                        onPageChanged: _onPageChanged,
                        itemCount: _kPages.length,
                        itemBuilder: (_, i) {
                          // Parallax offset for this page
                          final parallax = (_scrollOffset - i) * 60.0;
                          return _ImagePage(
                            data: _kPages[i],
                            parallaxOffset: parallax,
                            imageScale: i == _page ? _imageScale.value : 1.0,
                            imageFade: i == _page ? _imageFade.value : 1.0,
                          );
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Text content ────────────────────────────────────────
                Expanded(
                  flex: 7,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tag label
                        FadeTransition(
                          opacity: _tagFade,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(isDark ? 0.18 : 0.10),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              _kPages[_page].tag,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: accent,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Title
                        FadeTransition(
                          opacity: _titleFade,
                          child: SlideTransition(
                            position: _titleSlide,
                            child: Text(
                              _kPages[_page].title,
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Subtitle
                        FadeTransition(
                          opacity: _subtitleFade,
                          child: SlideTransition(
                            position: _subtitleSlide,
                            child: Text(
                              _kPages[_page].subtitle,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                                color: cs.onSurfaceVariant,
                                height: 1.65,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Bottom bar: dots + button ───────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 4, 28, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Dot indicators
                      Row(
                        children: List.generate(_kPages.length, (i) {
                          final active = i == _page;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            margin: const EdgeInsets.only(right: 7),
                            width: active ? 26 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(100),
                              color: active ? accent : cs.outlineVariant,
                            ),
                          );
                        }),
                      ),

                      // Next / Get Started
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        child: FilledButton(
                          onPressed: _next,
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: isLast ? 24 : 18,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                            ),
                            textStyle: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(isLast ? 'Get Started' : 'Next'),
                              const SizedBox(width: 6),
                              Icon(
                                isLast
                                    ? Icons.rocket_launch_rounded
                                    : Icons.arrow_forward_rounded,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Image page widget ─────────────────────────────────────────────────────────

class _ImagePage extends StatelessWidget {
  final _PageData data;
  final double parallaxOffset;
  final double imageScale;
  final double imageFade;

  const _ImagePage({
    required this.data,
    required this.parallaxOffset,
    required this.imageScale,
    required this.imageFade,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: imageScale,
      child: Opacity(
        opacity: imageFade.clamp(0.0, 1.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Parallax image
            Transform.translate(
              offset: Offset(parallaxOffset, 0),
              child: Image.asset(
                data.imageUrl,
                fit: BoxFit.cover,

                errorBuilder: (_, __, ___) =>
                    _ImagePlaceholder(accent: data.accent),
              ),
            ),

            // Bottom gradient overlay
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.45, 1.0],
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.55),
                  ],
                ),
              ),
            ),

            // Accent color tint strip at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      data.accent,
                      data.accent.withOpacity(0.4),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Image placeholder ─────────────────────────────────────────────────────────

class _ImagePlaceholder extends StatelessWidget {
  final Color accent;
  const _ImagePlaceholder({required this.accent});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withOpacity(isDark ? 0.25 : 0.15),
            accent.withOpacity(isDark ? 0.10 : 0.05),
          ],
        ),
      ),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation(accent),
        ),
      ),
    );
  }
}
