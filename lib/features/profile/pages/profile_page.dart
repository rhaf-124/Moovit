import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/theme.dart';
import '../../../core/utils/error_formatter.dart';
import '../../auth/data/models/user_model.dart';
import '../../auth/domain/repositories/auth_repository.dart';
import '../../auth/presentation/cubit/auth_cubit.dart';
import '../../auth/presentation/cubit/auth_state.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _stats;
  bool _statsLoading = true;
  bool _isUploadingPic = false;

  @override
  void initState() {
    super.initState();
    _refreshProfile(silent: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStats());
  }

  Future<void> _refreshProfile({bool silent = false}) async {
    try {
      await context.read<AuthCubit>().refreshProfile();
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _loadStats() async {
    try {
      final repo = RepositoryProvider.of<AuthRepository>(context);
      final stats = await repo.getStats();
      if (mounted) setState(() { _stats = stats; _statsLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;
    setState(() => _isUploadingPic = true);
    try {
      await context.read<AuthCubit>().uploadProfilePicture(picked.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPic = false);
    }
  }

  void _showHelpSupport(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tt = Theme.of(context).textTheme;
    final bg = isDark ? AppColors.darkSurface : AppColors.white;
    final border = isDark ? AppColors.darkOutline : AppColors.lightOutline;
    final subtle = isDark
        ? AppColors.darkOnSurfaceVariant
        : AppColors.lightOnSurfaceVariant;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: border, width: isDark ? 1 : 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.headset_mic_rounded,
                      color: AppColors.primary, size: 28),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text('Help & Support',
                    style: tt.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 20),
              Text('Contact Us',
                  style: tt.labelMedium?.copyWith(
                      color: subtle,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              _dialogContactRow(Icons.email_outlined, 'support@moovit.gh', tt),
              const SizedBox(height: 8),
              _dialogContactRow(
                  Icons.phone_outlined, '+233 30 000 0000', tt),
              const SizedBox(height: 20),
              Text('Common Questions',
                  style: tt.labelMedium?.copyWith(
                      color: subtle,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              ...[
                'How do I cancel a booking?',
                'When does my seat hold expire?',
                'How do I get a refund?',
                'Can I change my seat after booking?',
              ].map((q) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.arrow_right_rounded,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text(q, style: tt.bodySmall)),
                        ]),
                  )),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Close',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogContactRow(IconData icon, String text, TextTheme tt) {
    return Row(children: [
      Icon(icon, size: 18, color: AppColors.primary),
      const SizedBox(width: 10),
      Text(text,
          style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
    ]);
  }

  void _showPrivacyPolicy(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tt = Theme.of(context).textTheme;
    final bg = isDark ? AppColors.darkSurface : AppColors.white;
    final border = isDark ? AppColors.darkOutline : AppColors.lightOutline;
    final subtle = isDark
        ? AppColors.darkOnSurfaceVariant
        : AppColors.lightOnSurfaceVariant;

    const sections = [
      (
        'Data We Collect',
        'We collect your name, phone number, email address, and location data (when you grant permission) to provide our bus ticketing services.'
      ),
      (
        'How We Use Your Data',
        'Your data is used to process bookings, send ticket confirmations, and improve app performance. We do not sell your personal information to third parties.'
      ),
      (
        'Data Sharing',
        'We share necessary booking details with bus operators to fulfil your trip. Payment data is processed securely by our payment partners.'
      ),
      (
        'Data Retention',
        'We retain your booking history for 12 months. You may request deletion of your account data at any time by contacting support.'
      ),
      (
        'Your Rights',
        'You have the right to access, correct, or delete the personal data we hold about you. Contact us at support@moovit.gh to exercise these rights.'
      ),
      (
        'Contact',
        'For privacy concerns, reach us at privacy@moovit.gh or +233 30 000 0000.'
      ),
    ];

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: border, width: isDark ? 1 : 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined,
                    color: Colors.indigo, size: 28),
              ),
              const SizedBox(height: 16),
              Text('Privacy Policy',
                  style: tt.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Last updated: June 2026',
                  style: tt.bodySmall?.copyWith(color: subtle)),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: sections
                        .map((s) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 14),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(s.$1,
                                      style: tt.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  Text(s.$2,
                                      style: tt.bodySmall?.copyWith(
                                          color: subtle, height: 1.5)),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Close',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tt = Theme.of(context).textTheme;
    final bg = isDark ? AppColors.darkSurface : AppColors.white;
    final border = isDark ? AppColors.darkOutline : AppColors.lightOutline;
    final subtle = isDark
        ? AppColors.darkOnSurfaceVariant
        : AppColors.lightOnSurfaceVariant;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: border, width: isDark ? 1 : 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.directions_bus_rounded,
                    color: AppColors.primary, size: 40),
              ),
              const SizedBox(height: 16),
              Text('Moovit Bus Ticketing',
                  style: tt.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Version 1.0.0',
                  style: tt.bodySmall?.copyWith(color: subtle)),
              const SizedBox(height: 16),
              Text(
                'Your trusted platform for booking bus tickets across Ghana. '
                'Find trips, secure seats, and travel with confidence.',
                style: tt.bodySmall
                    ?.copyWith(color: subtle, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Divider(color: border),
              const SizedBox(height: 12),
              Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.copyright_rounded,
                        size: 14, color: subtle),
                    const SizedBox(width: 4),
                    Text('2026 Moovit Ltd. All rights reserved.',
                        style: tt.bodySmall?.copyWith(color: subtle)),
                  ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Close',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style:
                TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AuthCubit>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final isLoggingOut = authState is AuthLoggingOut;

        return Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                title: Text(
                  'Profile',
                  style:
                      tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              body: RefreshIndicator(
                onRefresh: () => _refreshProfile(silent: false),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Builder(builder: (context) {
                      final user = authState is AuthAuthenticated
                          ? authState.user
                          : null;
                      return _buildProfileHeader(isDark, tt, cs, user);
                    }),
                    const SizedBox(height: 24),

                    _sectionLabel('Preferences', tt),
                    const SizedBox(height: 8),
                    _buildMenuGroup(isDark, [
                      _MenuItem(
                        icon: Icons.dark_mode_outlined,
                        label: 'Dark Mode',
                        onTap: null,
                        trailing: Switch.adaptive(
                          value: isDark,
                          onChanged: (_) {
                            context
                                .read<ThemeBloc>()
                                .add(const ThemeToggled());
                          },
                        ),
                      ),
                      _MenuItem(
                        icon: Icons.language_outlined,
                        label: 'Language',
                        onTap: () {},
                        trailing: Text('English',
                            style: tt.bodySmall
                                ?.copyWith(color: AppColors.grey400)),
                      ),
                    ], tt, cs),

                    const SizedBox(height: 20),
                    _sectionLabel('Support', tt),
                    const SizedBox(height: 8),
                    _buildMenuGroup(isDark, [
                      _MenuItem(
                        icon: Icons.help_outline_rounded,
                        label: 'Help & Support',
                        onTap: () => _showHelpSupport(context),
                      ),
                      _MenuItem(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Privacy Policy',
                        onTap: () => _showPrivacyPolicy(context),
                      ),
                      _MenuItem(
                        icon: Icons.info_outline_rounded,
                        label: 'About',
                        onTap: () => _showAbout(context),
                      ),
                    ], tt, cs),

                    const SizedBox(height: 20),
                    _buildMenuGroup(isDark, [
                      _MenuItem(
                        icon: Icons.logout_rounded,
                        label: isLoggingOut ? 'Signing out...' : 'Sign Out',
                        onTap: isLoggingOut
                            ? null
                            : () => _confirmLogout(context),
                        labelColor: AppColors.error,
                        iconColor: AppColors.error,
                      ),
                    ], tt, cs),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            if (isLoggingOut)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black26,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        );
      },
    );
  }

  // ── Profile header ──────────────────────────────────────────────────────────

  Widget _buildProfileHeader(
    bool isDark,
    TextTheme tt,
    ColorScheme cs,
    UserModel? user,
  ) {
    final initials = user != null && user.fullName.isNotEmpty
        ? user.fullName
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join()
        : '?';

    final profileUrl = user?.profileImageUrl;
    final hasProfileImage = profileUrl != null && profileUrl.isNotEmpty;

    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: cs.primary.withValues(alpha: 0.14),
                backgroundImage: hasProfileImage
                    ? NetworkImage(profileUrl)
                    : null,
                child: hasProfileImage
                    ? null
                    : Text(
                        initials,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
              ),
              if (_isUploadingPic)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isUploadingPic ? null : _pickAndUploadImage,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _isUploadingPic
                          ? AppColors.grey400
                          : cs.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBackground
                            : AppColors.white,
                        width: 2,
                      ),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            user?.fullName ?? '—',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),

          Text(
            user?.email ?? '—',
            style: tt.bodyMedium?.copyWith(
              color: isDark
                  ? AppColors.darkOnSurfaceVariant
                  : AppColors.lightOnSurfaceVariant,
            ),
          ),

          if (user?.phone != null && user!.phone.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              user.phone,
              style: tt.bodySmall?.copyWith(color: AppColors.grey400),
            ),
          ],

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (user?.isVerified == true)
                _chip(
                  icon: Icons.verified_rounded,
                  label: 'Verified',
                  color: Colors.green,
                  isDark: isDark,
                  tt: tt,
                ),
              if (user?.isVerified == true && user?.role != null)
                const SizedBox(width: 8),
              if (user?.role != null)
                _chip(
                  icon: Icons.badge_outlined,
                  label: _capitalise(user!.role),
                  color: cs.primary,
                  isDark: isDark,
                  tt: tt,
                ),
            ],
          ),

          const SizedBox(height: 16),
          _buildStatsRow(isDark, tt, cs),
        ],
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required TextTheme tt,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

  Widget _buildStatsRow(bool isDark, TextTheme tt, ColorScheme cs) {
    final bg = isDark ? AppColors.darkSurface : AppColors.white;
    final border = isDark ? AppColors.darkOutline : AppColors.lightOutline;

    final total = _stats?['total_bookings'] as int? ?? 0;
    final upcoming = _stats?['upcoming_bookings'] as int? ?? 0;
    final spent = (_stats?['total_spent'] as num?)?.toStringAsFixed(0) ?? '0';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: _statsLoading
              ? [
                  _statItemLoading(tt, border),
                  VerticalDivider(color: border, width: 1),
                  _statItemLoading(tt, border),
                  VerticalDivider(color: border, width: 1),
                  _statItemLoading(tt, border),
                ]
              : [
                  _statItem(total.toString(), 'Trips', tt, cs),
                  VerticalDivider(color: border, width: 1),
                  _statItem(upcoming.toString(), 'Upcoming', tt, cs),
                  VerticalDivider(color: border, width: 1),
                  _statItem('GH₵$spent', 'Spent', tt, cs),
                ],
        ),
      ),
    );
  }

  Widget _statItemLoading(TextTheme tt, Color border) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 18,
            width: 40,
            decoration: BoxDecoration(
              color: border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 12,
            width: 50,
            decoration: BoxDecoration(
              color: border.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(
      String value, String label, TextTheme tt, ColorScheme cs) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: tt.bodySmall?.copyWith(color: AppColors.grey400),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, TextTheme tt) {
    return Text(
      label.toUpperCase(),
      style: tt.labelSmall?.copyWith(
        color: AppColors.grey400,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildMenuGroup(
    bool isDark,
    List<_MenuItem> items,
    TextTheme tt,
    ColorScheme cs,
  ) {
    final cardColor = isDark ? AppColors.darkSurface : AppColors.white;
    final borderColor =
        isDark ? AppColors.darkOutline : AppColors.lightOutline;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: items.indexed.map((entry) {
          final i = entry.$1;
          final item = entry.$2;
          return Column(
            children: [
              ListTile(
                onTap: item.onTap,
                leading: Icon(
                  item.icon,
                  size: 22,
                  color: item.iconColor ??
                      (isDark
                          ? AppColors.darkOnSurface
                          : AppColors.lightOnSurface),
                ),
                title: Text(
                  item.label,
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: item.labelColor,
                  ),
                ),
                trailing: item.trailing ??
                    (item.onTap != null
                        ? Icon(Icons.chevron_right_rounded,
                            color: AppColors.grey400, size: 20)
                        : null),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top:
                        i == 0 ? const Radius.circular(14) : Radius.zero,
                    bottom: i == items.length - 1
                        ? const Radius.circular(14)
                        : Radius.zero,
                  ),
                ),
              ),
              if (i < items.length - 1)
                Divider(
                  height: 1,
                  indent: 56,
                  color: borderColor,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

}

class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? labelColor;
  final Color? iconColor;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.labelColor,
    this.iconColor,
  });
}
