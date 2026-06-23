import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_formatter.dart';
import '../domain/repositories/driver_repository.dart';
import '../models/driver_trip_model.dart';
import 'driver_dashboard_page.dart'; // To reuse TripStatus constants

class DriverTicketsPage extends StatefulWidget {
  const DriverTicketsPage({super.key});

  @override
  State<DriverTicketsPage> createState() => _DriverTicketsPageState();
}

class _DriverTicketsPageState extends State<DriverTicketsPage> {
  bool _isLoading = true;
  String? _error;
  List<DriverTripModel> _trips = [];
  String _filter = 'active'; // active, completed, all

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = RepositoryProvider.of<DriverRepository>(context);
      final trips = await repo.getDriverTrips();
      if (mounted) {
        setState(() {
          _trips = trips;
          _isLoading = false;
        });
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

  List<DriverTripModel> get _filteredTrips {
    if (_filter == 'active') {
      return _trips.where((t) =>
          t.status == TripStatus.scheduled ||
          t.status == TripStatus.boarding ||
          t.status == TripStatus.inProgress).toList();
    } else if (_filter == 'completed') {
      return _trips.where((t) =>
          t.status == TripStatus.completed ||
          t.status == TripStatus.cancelled).toList();
    }
    return _trips;
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

  // ── Skeleton ─────────────────────────────────────────────────────────────────

  Widget _buildSkeleton(bool isDark) {
    final base = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final highlight = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (_, _) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
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
                  _sBox(height: 12, width: 170, radius: 6),
                  const SizedBox(height: 8),
                  _sBox(height: 12, width: 140, radius: 6),
                  const SizedBox(height: 12),
                  _sBox(height: 16, width: 110, radius: 6),
                ]),
              ),
            ]),
          ),
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF080F1E) : const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(
          'My Trips & Routes',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _loadTrips,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Filter Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('Active', 'active'),
                const SizedBox(width: 8),
                _buildFilterChip('Completed', 'completed'),
                const SizedBox(width: 8),
                _buildFilterChip('All Trips', 'all'),
              ],
            ),
          ),
          
          // Trips list
          Expanded(
            child: _isLoading
                ? _buildSkeleton(isDark)
                : _error != null
                    ? _buildError(tt)
                    : _filteredTrips.isEmpty
                        ? _buildEmptyState(tt)
                        : RefreshIndicator(
                            onRefresh: _loadTrips,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredTrips.length,
                              itemBuilder: (context, index) {
                                final trip = _filteredTrips[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _buildTripCard(trip, isDark, tt),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (val) {
        if (val) {
          setState(() {
            _filter = value;
          });
        }
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      showCheckmark: false,
    );
  }

  String _resolveImageUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return rawUrl;
    final base = ApiConstants.baseUrl.replaceAll(RegExp(r'/$'), '');
    return '$base${uri.path}';
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
          // ── Bus image ──────────────────────────────────────────────────────
          if (trip.busImageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: SizedBox(
                height: 110,
                width: double.infinity,
                child: Image.network(
                  _resolveImageUrl(trip.busImageUrl!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                _infoRow(Icons.access_time_rounded, AppColors.primary, '$depTime → $arrTime', tt),
                const SizedBox(height: 6),
                _infoRow(Icons.directions_bus_rounded, Colors.blue, '${trip.busModel} · ${trip.busPlate}', tt),
                const SizedBox(height: 6),
                _infoRow(Icons.route_rounded, Colors.purple, '${trip.routeDistanceKm.toStringAsFixed(1)} km · ${trip.routeDurationMinutes} min', tt),
                const SizedBox(height: 6),
                _infoRow(Icons.airline_seat_recline_normal_rounded, Colors.green, '${trip.availableSeats} seats available', tt),
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
                    if (trip.status == TripStatus.inProgress)
                      Row(
                        children: [
                          Icon(Icons.circle, color: AppColors.success, size: 8),
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
                if (nextStatuses.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
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
                  ),
                ],
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
        Expanded(child: Text(text, style: tt.bodySmall?.copyWith(color: AppColors.grey600))),
      ],
    );
  }

  IconData _statusIcon(String s) => switch (s) {
        TripStatus.boarding => Icons.door_sliding_rounded,
        TripStatus.inProgress => Icons.play_arrow_rounded,
        TripStatus.completed => Icons.check_circle_rounded,
        TripStatus.cancelled => Icons.cancel_rounded,
        _ => Icons.circle,
      };

  Widget _buildError(TextTheme tt) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text('Error loading trips', style: tt.titleMedium),
          const SizedBox(height: 8),
          Text(_error ?? 'Please check your connection', style: tt.bodySmall),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadTrips, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyState(TextTheme tt) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_bus_outlined, size: 64, color: AppColors.grey400),
          const SizedBox(height: 16),
          Text('No trips found', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('There are no trips matching this category.', style: tt.bodySmall?.copyWith(color: AppColors.grey500)),
        ],
      ),
    );
  }
}
