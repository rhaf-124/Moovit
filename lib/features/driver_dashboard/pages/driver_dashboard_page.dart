import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_cubit.dart';
import '../../../core/utils/error_formatter.dart';
import '../domain/repositories/driver_repository.dart';
import '../models/driver_profile_model.dart';
import '../models/driver_trip_model.dart';

// ── Trip status constants ────────────────────────────────────────────────────

abstract final class TripStatus {
  static const scheduled = 'scheduled';
  static const boarding = 'boarding';
  static const inProgress = 'in_progress';
  static const halted = 'halted';
  static const completed = 'completed';
  static const cancelled = 'cancelled';

  static const allStatuses = [
    scheduled,
    boarding,
    inProgress,
    halted,
    completed,
    cancelled,
  ];

  static String label(String status) => switch (status) {
        scheduled => 'Scheduled',
        boarding => 'Boarding',
        inProgress => 'In Progress',
        halted => 'Halted',
        completed => 'Completed',
        cancelled => 'Cancelled',
        _ => status,
      };

  static Color color(String status) => switch (status) {
        scheduled => Colors.blue,
        boarding => Colors.orange,
        inProgress => Colors.green,
        halted => Colors.deepOrange,
        completed => Colors.grey,
        cancelled => Colors.red,
        _ => Colors.blueGrey,
      };

  /// Returns the statuses a driver can transition to from the current status
  static List<String> nextAllowed(String current) => switch (current) {
        scheduled => [boarding],
        boarding => [inProgress, halted],
        inProgress => [completed, halted],
        halted => [inProgress],
        _ => [],
      };
}

// ── Page ─────────────────────────────────────────────────────────────────────

class DriverDashboardPage extends StatefulWidget {
  const DriverDashboardPage({super.key});

  @override
  State<DriverDashboardPage> createState() => _DriverDashboardPageState();
}

class _DriverDashboardPageState extends State<DriverDashboardPage> {
  bool _isOnline = false;

  bool _isLoading = true;
  String? _error;
  List<DriverTripModel> _trips = [];
  DriverProfileModel? _profile;

  // Live location state
  Timer? _locationTimer;
  bool _locationPermissionDenied = false;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  bool _isTodayTrip(DriverTripModel trip) {
    final now = DateTime.now();
    final dep = trip.departureTime.toLocal();
    return dep.year == now.year && dep.month == now.month && dep.day == now.day;
  }

  // ── Data loading ────────────────────────────────────────────────────────────

  Future<void> _loadTrips() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = RepositoryProvider.of<DriverRepository>(context);
      // Load profile and trips in parallel for speed
      final results = await Future.wait([
        repo.getDriverProfile(),
        repo.getDriverTrips(),
      ]);
      if (mounted) {
        setState(() {
          _profile = results[0] as DriverProfileModel;
          _trips = results[1] as List<DriverTripModel>;
          _isOnline = (_profile as DriverProfileModel).isAvailable;
          _isLoading = false;
        });
        _syncLocationTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyError(e);
          _isLoading = false;
        });
      }
    }
  }

  /// Strips the hardcoded server origin from a URL returned by the API and
  /// replaces it with the project's configured [ApiConstants.baseUrl].
  /// This ensures the app works across emulator, physical device, and staging.
  String _resolveImageUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return rawUrl;
    // Keep only the path+query portion and prepend our base URL
    final base = ApiConstants.baseUrl.replaceAll(RegExp(r'/$'), '');
    return '$base${uri.path}';
  }

  // ── Live location ────────────────────────────────────────────────────────────

  /// Starts/stops the 10-second location push depending on whether any trip
  /// is currently `in_progress`, `boarding`, or `scheduled` and is today.
  void _syncLocationTimer() {
    final hasActive = _trips.any((t) =>
        (t.status == TripStatus.inProgress ||
            t.status == TripStatus.boarding ||
            t.status == TripStatus.scheduled) &&
        _isTodayTrip(t));
    if (hasActive && _locationTimer == null) {
      _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _pushLocationForActiveTrips();
      });
    } else if (!hasActive) {
      _locationTimer?.cancel();
      _locationTimer = null;
    }
  }

  Future<void> _pushLocationForActiveTrips() async {
    // 1. Ensure location services are on
    if (!await Geolocator.isLocationServiceEnabled()) {
      debugPrint('[Location] Services disabled');
      return;
    }

    // 2. Check / request permission
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      if (mounted) setState(() => _locationPermissionDenied = true);
      _locationTimer?.cancel();
      _locationTimer = null;
      return;
    }

    if (mounted && _locationPermissionDenied) {
      setState(() => _locationPermissionDenied = false);
    }

    // 3. Get real GPS position
    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (e) {
      debugPrint('[Location] Could not get position: $e');
      return;
    }

    // 4. Push to backend for every active trip
    if (!mounted) return;
    final repo = RepositoryProvider.of<DriverRepository>(context);
    final List<DriverTripModel> reassignedTrips = [];
    for (final trip in List.of(_trips)) {
      if ((trip.status == TripStatus.inProgress ||
              trip.status == TripStatus.boarding ||
              trip.status == TripStatus.scheduled) &&
          _isTodayTrip(trip)) {
        try {
          await repo.updateTripLocation(
            tripId: trip.id,
            latitude: position.latitude,
            longitude: position.longitude,
          );
          debugPrint('[Location] Pushed (${position.latitude.toStringAsFixed(5)}, '
              '${position.longitude.toStringAsFixed(5)}) for trip ${trip.id}');
        } catch (e) {
          if (e is DioException &&
              (e.response?.statusCode == 404 || e.response?.statusCode == 403)) {
            // Backend rejected this trip — it was reassigned to another driver.
            reassignedTrips.add(trip);
          } else {
            debugPrint('[Location] Failed to push: $e');
          }
        }
      }
    }

    if (mounted && reassignedTrips.isNotEmpty) {
      setState(() {
        for (final t in reassignedTrips) {
          _trips.removeWhere((x) => x.id == t.id);
        }
      });
      _syncLocationTimer();
      final first = reassignedTrips.first;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Trip ${first.routeOrigin} → ${first.routeDestination} has been reassigned.'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ));
    }
  }

  // ── Status update ────────────────────────────────────────────────────────────

  Future<void> _updateStatus(DriverTripModel trip, String newStatus) async {
    final repo = RepositoryProvider.of<DriverRepository>(context);
    try {
      final updated = await repo.updateTripStatus(
        tripId: trip.id,
        status: newStatus,
      );
      if (mounted) {
        setState(() {
          final idx = _trips.indexWhere((t) => t.id == updated.id);
          if (idx != -1) _trips[idx] = updated;
        });
        _syncLocationTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trip status updated to ${TripStatus.label(updated.status)}'),
            backgroundColor: TripStatus.color(updated.status),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update trip status. ${friendlyError(e)}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080F1E) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(
          'Driver Dashboard',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.myDriverReports),
            icon: const Icon(Icons.report_problem_rounded),
            tooltip: 'My Reports',
          ),
          IconButton(
            onPressed: () {
              context.read<ThemeBloc>().add(const ThemeToggled());
            },
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
            tooltip: 'Toggle Theme',
          ),
          IconButton(
            onPressed: _loadTrips,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: _isLoading
          ? _buildSkeleton(isDark)
          : _error != null
              ? _buildError(tt, cs)
              : RefreshIndicator(
                  onRefresh: _loadTrips,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileStatusCard(isDark, tt),
                        const SizedBox(height: 24),
                        _buildStatsGrid(tt, isDark),
                        const SizedBox(height: 24),
                        _buildLiveLocationBanner(isDark, tt),
                        const SizedBox(height: 24),
                        ..._buildTripSections(tt, isDark),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  // ── Skeleton loading ─────────────────────────────────────────────────────────

  Widget _buildSkeleton(bool isDark) {
    final base = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final highlight = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile card skeleton
            _sBox(height: 110, radius: 24),
            const SizedBox(height: 12),
            // Assigned bus skeleton
            _sBox(height: 80, radius: 20),
            const SizedBox(height: 24),
            // Stats grid skeleton
            Row(children: [
              Expanded(child: _sBox(height: 110, radius: 20)),
              const SizedBox(width: 12),
              Expanded(child: _sBox(height: 110, radius: 20)),
              const SizedBox(width: 12),
              Expanded(child: _sBox(height: 110, radius: 20)),
            ]),
            const SizedBox(height: 24),
            // Section label
            _sBox(height: 14, width: 160, radius: 6),
            const SizedBox(height: 12),
            // Trip card skeletons
            ...[1, 2].map((_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _sTripCard(),
            )),
          ],
        ),
      ),
    );
  }

  Widget _sTripCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: [
        // Image placeholder
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Container(height: 100, color: Colors.white),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: _sBox(height: 16, radius: 6)),
              const SizedBox(width: 12),
              _sBox(height: 22, width: 70, radius: 20),
            ]),
            const SizedBox(height: 12),
            _sBox(height: 12, width: double.infinity, radius: 6),
            const SizedBox(height: 8),
            _sBox(height: 12, width: 200, radius: 6),
            const SizedBox(height: 8),
            _sBox(height: 12, width: 160, radius: 6),
            const SizedBox(height: 8),
            _sBox(height: 12, width: 140, radius: 6),
            const SizedBox(height: 12),
            _sBox(height: 16, width: 100, radius: 6),
          ]),
        ),
      ]),
    );
  }

  Widget _sBox({required double height, double? width, double radius = 8}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────────

  Widget _buildError(TextTheme tt, ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.errorSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 48),
            ),
            const SizedBox(height: 16),
            Text('Failed to load trips',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(_error ?? 'An unexpected error occurred',
                style: tt.bodySmall?.copyWith(color: AppColors.grey500),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadTrips,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileStatusCard(bool isDark, TextTheme tt) {
    final cardColor = isDark ? AppColors.darkSurface : AppColors.white;
    final profile = _profile;

    // ── Profile avatar ──────────────────────────────────────────────────────
    Widget avatar;
    if (profile?.profileImageUrl != null) {
      avatar = CircleAvatar(
        radius: 30,
        backgroundColor: Colors.indigo.shade100,
        backgroundImage:
            NetworkImage(_resolveImageUrl(profile!.profileImageUrl!)),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    } else {
      avatar = CircleAvatar(
        radius: 30,
        backgroundColor: Colors.indigo.shade100,
        child: const Icon(Icons.person_outline, size: 36, color: Colors.indigo),
      );
    }

    return Column(
      children: [
        // ── Driver info row ─────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              avatar,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile != null
                          ? 'Hi, ${profile.fullName.split(' ').first}!'
                          : 'Welcome, Driver!',
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (profile != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        profile.phone,
                        style: tt.bodySmall
                            ?.copyWith(color: AppColors.grey500),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _isOnline ? 'You are online' : 'You are offline',
                      style: tt.bodySmall?.copyWith(
                        color:
                            _isOnline ? AppColors.success : AppColors.grey500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _isOnline,
                onChanged: (val) => setState(() => _isOnline = val),
              ),
            ],
          ),
        ),

        // ── Assigned bus card ────────────────────────────────────────────────
        if (profile?.assignedBus != null) ...[
          const SizedBox(height: 12),
          _buildAssignedBusCard(profile!.assignedBus!, isDark, tt),
        ],
      ],
    );
  }

  Widget _buildAssignedBusCard(
      AssignedBusModel bus, bool isDark, TextTheme tt) {
    final cardColor = isDark ? AppColors.darkSurface : AppColors.white;
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
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
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          // Bus image
          if (bus.imageUrl != null)
            SizedBox(
              width: 90,
              height: 80,
              child: Image.network(
                _resolveImageUrl(bus.imageUrl!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.indigo.shade50,
                  child: const Icon(Icons.directions_bus_rounded,
                      color: Colors.indigo, size: 36),
                ),
              ),
            )
          else
            Container(
              width: 90,
              height: 80,
              color: Colors.indigo.shade50,
              child: const Icon(Icons.directions_bus_rounded,
                  color: Colors.indigo, size: 36),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assigned Bus',
                    style: tt.labelSmall
                        ?.copyWith(color: AppColors.grey500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bus.model,
                    style: tt.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${bus.plateNumber}  ·  ${bus.capacity} seats',
                    style: tt.bodySmall
                        ?.copyWith(color: AppColors.grey500),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(TextTheme tt, bool isDark) {
    final totalTrips = _trips.length;
    final completedTrips =
        _trips.where((t) => t.status == TripStatus.completed).length;
    final activeTrips = _trips
        .where((t) =>
            t.status == TripStatus.inProgress ||
            t.status == TripStatus.boarding)
        .length;
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Total Trips',
            value: '$totalTrips',
            icon: Icons.alt_route_rounded,
            color: Colors.blue,
            isDark: isDark,
            tt: tt,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Completed',
            value: '$completedTrips',
            icon: Icons.check_circle_outline_rounded,
            color: Colors.teal,
            isDark: isDark,
            tt: tt,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'Active Now',
            value: '$activeTrips',
            icon: Icons.directions_bus_rounded,
            color: Colors.green,
            isDark: isDark,
            tt: tt,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
    required TextTheme tt,
  }) {
    final cardColor = isDark ? AppColors.darkSurface : AppColors.white;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            radius: 20,
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          Text(value,
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title,
              style: tt.bodySmall?.copyWith(color: AppColors.grey500)),
        ],
      ),
    );
  }

  Widget _buildLiveLocationBanner(bool isDark, TextTheme tt) {
    final hasActive = _trips.any((t) =>
        (t.status == TripStatus.inProgress ||
            t.status == TripStatus.boarding ||
            t.status == TripStatus.scheduled) &&
        _isTodayTrip(t));
    if (!hasActive) return const SizedBox.shrink();

    if (_locationPermissionDenied) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.location_off_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Location permission denied. Passengers cannot see your position.',
              style: tt.bodySmall?.copyWith(
                  color: AppColors.error, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Geolocator.openAppSettings(),
            child: Text('Allow',
                style: tt.labelSmall?.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline)),
          ),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded,
              color: AppColors.success, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Live location is being shared every 10 seconds.',
              style: tt.bodySmall?.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _PulsingDot(),
        ],
      ),
    );
  }

  List<Widget> _buildTripSections(TextTheme tt, bool isDark) {
    const activeStatuses = {
      TripStatus.scheduled,
      TripStatus.boarding,
      TripStatus.inProgress,
      TripStatus.halted,
    };
    final active = _trips.where((t) => activeStatuses.contains(t.status)).toList();
    final history = _trips
        .where((t) => t.status == TripStatus.completed || t.status == TripStatus.cancelled)
        .toList();

    return [
      Text(
        'Active & Upcoming Trips',
        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      if (active.isEmpty)
        _buildEmptyTrips(tt, isDark, 'No active or upcoming trips.')
      else
        ...active.map((trip) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildTripCard(trip, isDark, tt),
            )),
      if (history.isNotEmpty) ...[
        const SizedBox(height: 24),
        Row(
          children: [
            Text(
              'Trip History',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${history.length}',
                style: tt.labelSmall?.copyWith(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...history.map((trip) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildTripCard(trip, isDark, tt),
            )),
      ],
    ];
  }

  Widget _buildEmptyTrips(TextTheme tt, bool isDark,
      [String message = 'You have no upcoming or today\'s trips.']) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.event_busy_rounded, size: 48, color: AppColors.grey400),
          const SizedBox(height: 12),
          Text('No trips',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(message,
              style: tt.bodySmall?.copyWith(color: AppColors.grey500),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildTripCard(DriverTripModel trip, bool isDark, TextTheme tt) {
    final cardColor = isDark ? AppColors.darkSurface : AppColors.white;
    final statusColor = TripStatus.color(trip.status);
    final nextStatuses = TripStatus.nextAllowed(trip.status);

    final depTime = _fmtTime(trip.departureTime);
    final arrTime = trip.arrivalTime != null ? _fmtTime(trip.arrivalTime!) : '--:--';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Bus image banner ─────────────────────────────────────────────
          if (trip.busImageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: SizedBox(
                height: 110,
                width: double.infinity,
                child: Image.network(
                  _resolveImageUrl(trip.busImageUrl!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.indigo.shade50,
                    child: const Icon(Icons.directions_bus_rounded,
                        color: Colors.indigo, size: 40),
                  ),
                ),
              ),
            )
          else
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Container(
                height: 80,
                width: double.infinity,
                color: Colors.indigo.shade50,
                child: const Icon(Icons.directions_bus_rounded,
                    color: Colors.indigo, size: 40),
              ),
            ),

          Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${trip.routeOrigin} → ${trip.routeDestination}',
                    style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    TripStatus.label(trip.status),
                    style: tt.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Info rows ────────────────────────────────────────────────────
            _infoRow(Icons.access_time_rounded, AppColors.primary,
                '$depTime → $arrTime', tt),
            const SizedBox(height: 6),
            _infoRow(Icons.directions_bus_rounded, Colors.blue,
                '${trip.busModel} · ${trip.busPlate}', tt),
            const SizedBox(height: 6),
            _infoRow(Icons.route_rounded, Colors.purple,
                '${trip.routeDistanceKm.toStringAsFixed(1)} km · ${trip.routeDurationMinutes} min',
                tt),
            const SizedBox(height: 6),
            if (trip.status != TripStatus.completed && trip.status != TripStatus.cancelled)
              _infoRow(Icons.airline_seat_recline_normal_rounded, Colors.green,
                  '${trip.availableSeats} seats available', tt),

            // ── Fare ──────────────────────────────────────────────────────────
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Fare: GH₵ ${trip.fare.toStringAsFixed(2)}',
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                if ((trip.status == TripStatus.inProgress ||
                        trip.status == TripStatus.boarding ||
                        trip.status == TripStatus.scheduled) &&
                    _isTodayTrip(trip))
                  Row(
                    children: [
                      Icon(Icons.circle,
                          color: AppColors.success, size: 8),
                      const SizedBox(width: 4),
                      Text(
                        'Tracking live',
                        style: tt.labelSmall?.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
              ],
            ),

            // ── Action buttons ──────────────────────────────────────────────
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => context.push(
                    AppRoutes.submitDriverReport,
                    extra: trip,
                  ),
                  icon: const Icon(Icons.report_problem_outlined, size: 15),
                  label: const Text('Report Issue', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                if (nextStatuses.isNotEmpty) ...[
                  const Spacer(),
                  ...nextStatuses.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ElevatedButton.icon(
                        onPressed: () => _updateStatus(trip, s),
                        icon: Icon(_statusIcon(s), size: 16, color: Colors.white),
                        label: Text(
                          TripStatus.label(s),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TripStatus.color(s),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, Color color, String text, TextTheme tt) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: tt.bodySmall?.copyWith(color: AppColors.grey600))),
      ],
    );
  }

  IconData _statusIcon(String s) => switch (s) {
        TripStatus.boarding => Icons.door_sliding_rounded,
        TripStatus.inProgress => Icons.play_arrow_rounded,
        TripStatus.halted => Icons.pause_circle_rounded,
        TripStatus.completed => Icons.check_circle_rounded,
        TripStatus.cancelled => Icons.cancel_rounded,
        _ => Icons.update_rounded,
      };

  String _fmtTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }
}

// ── Pulsing dot indicator ────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _anim,
        child: const Icon(Icons.circle, color: AppColors.success, size: 10),
      );
}
