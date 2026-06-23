import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/theme.dart';
import '../../auth/presentation/cubit/auth_cubit.dart';
import '../../auth/presentation/cubit/auth_state.dart';
import '../domain/repositories/driver_repository.dart';
import '../models/driver_profile_model.dart';

class DriverSettingsPage extends StatefulWidget {
  const DriverSettingsPage({super.key});

  @override
  State<DriverSettingsPage> createState() => _DriverSettingsPageState();
}

class _DriverSettingsPageState extends State<DriverSettingsPage> {
  DriverProfileModel? _profile;
  bool _loadingProfile = true;
  bool _isUploadingPic = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  Future<void> _loadProfile() async {
    try {
      final repo = RepositoryProvider.of<DriverRepository>(context);
      final profile = await repo.getDriverProfile();
      if (mounted) setState(() { _profile = profile; _loadingProfile = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _pickAndUploadDriverImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;
    setState(() => _isUploadingPic = true);
    try {
      final repo = RepositoryProvider.of<DriverRepository>(context);
      final updated = await repo.uploadProfilePicture(picked.path);
      if (mounted) setState(() => _profile = updated);
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
            content: Text(e.toString()),
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
              _contactRow(
                  Icons.email_outlined, 'driver-support@moovit.gh', tt),
              const SizedBox(height: 8),
              _contactRow(Icons.phone_outlined, '+233 30 000 0001', tt),
              const SizedBox(height: 20),
              Text('Common Questions',
                  style: tt.labelMedium?.copyWith(
                      color: subtle,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              ...[
                'How do I start a trip?',
                'What if the QR code fails to scan?',
                'How do I report a passenger issue?',
                'How is my location shared?',
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

  Widget _contactRow(IconData icon, String text, TextTheme tt) {
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
        'We collect your name, phone number, email address, and GPS location data during active trips to support live tracking.'
      ),
      (
        'How We Use Your Data',
        'Your location is shared with passengers in real time only while a trip is in progress. No background tracking occurs outside of active trips.'
      ),
      (
        'Data Sharing',
        'Trip and location data is shared with passengers who hold valid bookings for your assigned trip. It is not shared with third parties.'
      ),
      (
        'Data Retention',
        'Trip records are retained for 12 months. You may request deletion of your account data at any time.'
      ),
      (
        'Your Rights',
        'You have the right to access, correct, or delete your personal data. Contact us at privacy@moovit.gh.'
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
                constraints: const BoxConstraints(maxHeight: 300),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: sections
                        .map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
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
              Text('Driver App · Version 1.0.0',
                  style: tt.bodySmall?.copyWith(color: subtle)),
              const SizedBox(height: 16),
              Text(
                'Empowering drivers across Ghana with real-time trip management, '
                'live location sharing, and seamless ticket scanning.',
                style: tt.bodySmall?.copyWith(color: subtle, height: 1.5),
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
      barrierDismissible: true,
      builder: (ctx) {
        final tt = Theme.of(ctx).textTheme;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final bg = isDark ? AppColors.darkSurface : AppColors.white;
        final border = isDark ? AppColors.darkOutline : AppColors.lightOutline;

        return Dialog(
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
                    color: AppColors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.error,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Sign Out',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to sign out? You will need to log in again to manage trips and scan tickets.',
                  style: tt.bodyMedium?.copyWith(
                    color: AppColors.grey500,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(color: border),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkOnSurface
                                : AppColors.lightOnSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Sign Out',
                          style:
                              TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
        final authUser =
            authState is AuthAuthenticated ? authState.user : null;

        // Prefer loaded driver profile data, fall back to auth user info
        final displayName =
            _profile?.fullName ?? authUser?.fullName ?? 'Driver Profile';
        final displayEmail =
            _profile?.email ?? authUser?.email ?? '';
        final profileUrl = _profile?.profileImageUrl;
        final hasProfileImage =
            profileUrl != null && profileUrl.isNotEmpty;

        final initials = displayName.isNotEmpty
            ? displayName
                .trim()
                .split(RegExp(r'\s+'))
                .take(2)
                .map((w) => w[0].toUpperCase())
                .join()
            : '?';

        final isLoggingOut = authState is AuthLoggingOut;

        return Stack(
          children: [
        Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF080F1E) : const Color(0xFFF3F4F6),
          appBar: AppBar(
            title: Text(
              'Settings',
              style:
                  tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Driver Profile Header ─────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color:
                      isDark ? AppColors.darkSurface : AppColors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: isDark
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Row(
                  children: [
                    // Avatar with edit button
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor:
                              cs.primary.withValues(alpha: 0.12),
                          backgroundImage: hasProfileImage
                              ? NetworkImage(profileUrl)
                              : null,
                          child: hasProfileImage
                              ? null
                              : (_loadingProfile
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: cs.primary,
                                      ),
                                    )
                                  : Text(
                                      initials,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: cs.primary,
                                      ),
                                    )),
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
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
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
                            onTap: _isUploadingPic
                                ? null
                                : _pickAndUploadDriverImage,
                            child: Container(
                              width: 24,
                              height: 24,
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
                              child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: tt.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayEmail,
                            style: tt.bodySmall
                                ?.copyWith(color: AppColors.grey500),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  cs.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              'Driver Mode',
                              style: tt.labelSmall?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Preferences ───────────────────────────────────────────
              _sectionLabel('Preferences', tt),
              const SizedBox(height: 8),
              _buildMenuGroup(isDark, [
                _MenuItem(
                  icon: Icons.dark_mode_outlined,
                  label: 'Dark Mode',
                  onTap: null,
                  trailing: Switch.adaptive(
                    value: isDark,
                    onChanged: (val) {
                      context
                          .read<ThemeBloc>()
                          .add(const ThemeToggled());
                    },
                  ),
                ),
                // _MenuItem(
                //   icon: Icons.notifications_none_rounded,
                //   label: 'Notifications',
                //   onTap: () {
                //     ScaffoldMessenger.of(context).showSnackBar(
                //       const SnackBar(
                //         content:
                //             Text('Notification settings coming soon'),
                //         behavior: SnackBarBehavior.floating,
                //       ),
                //     );
                //   },
                // ),
              ], tt),
              const SizedBox(height: 20),

              // ── Support & Legals ──────────────────────────────────────
              _sectionLabel('Support & Legals', tt),
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
              ], tt),
              const SizedBox(height: 20),

              // ── Sign Out ──────────────────────────────────────────────
              _buildMenuGroup(isDark, [
                _MenuItem(
                  icon: Icons.logout_rounded,
                  label: 'Sign Out',
                  onTap: () => _confirmLogout(context),
                  labelColor: AppColors.error,
                  iconColor: AppColors.error,
                ),
              ], tt),
            ],
          ),
        ),
        if (isLoggingOut)
          Container(
            color: Colors.black54,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text(
                      'Signing out...',
                      style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Please wait a moment',
                      style: tt.bodySmall?.copyWith(color: AppColors.grey500),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
      },
    );
  }

  Widget _sectionLabel(String label, TextTheme tt) {
    return Text(
      label.toUpperCase(),
      style: tt.labelSmall?.copyWith(
        color: AppColors.grey500,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildMenuGroup(
    bool isDark,
    List<_MenuItem> items,
    TextTheme tt,
  ) {
    final cardColor = isDark ? AppColors.darkSurface : AppColors.white;
    final borderColor =
        isDark ? AppColors.darkOutline : AppColors.lightOutline;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
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
                    top: i == 0
                        ? const Radius.circular(16)
                        : Radius.zero,
                    bottom: i == items.length - 1
                        ? const Radius.circular(16)
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
