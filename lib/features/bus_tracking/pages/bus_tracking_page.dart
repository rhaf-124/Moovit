import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../bus_search/domain/repositories/trip_repository.dart';
import '../../bus_search/models/trip_live_location.dart';

class BusTrackingPage extends StatefulWidget {
  final String tripId;
  const BusTrackingPage({super.key, required this.tripId});

  @override
  State<BusTrackingPage> createState() => _BusTrackingPageState();
}

class _BusTrackingPageState extends State<BusTrackingPage> {
  TripLiveLocation? _location;
  LatLng? _destinationLatLng;
  bool _isLoading = true;
  String? _error;
  DateTime? _lastUpdated;
  Timer? _pollTimer;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAndUpdate();
      _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _fetchAndUpdate();
      });
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchAndUpdate() async {
    try {
      final repo = RepositoryProvider.of<TripRepository>(context);
      final loc = await repo.getTripLiveLocation(widget.tripId);
      if (!mounted) return;

      LatLng? destLatLng = _destinationLatLng;
      if (destLatLng == null && loc.destination.isNotEmpty) {
        destLatLng = await _geocode(loc.destination);
      }

      setState(() {
        _location = loc;
        _destinationLatLng = destLatLng;
        _lastUpdated = DateTime.now();
        _isLoading = false;
        _error = null;
      });

      _fitMap();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Could not fetch bus location.';
        });
      }
    }
  }

  Future<LatLng?> _geocode(String cityName) async {
    try {
      final dio = Dio();
      final resp = await dio.get<List<dynamic>>(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {'q': cityName, 'format': 'json', 'limit': '1'},
        options: Options(headers: {'User-Agent': 'BusTicketingApp/1.0'}),
      );
      final results = resp.data;
      if (results != null && results.isNotEmpty) {
        final first = results.first as Map<String, dynamic>;
        final lat = double.tryParse(first['lat'].toString());
        final lon = double.tryParse(first['lon'].toString());
        if (lat != null && lon != null) return LatLng(lat, lon);
      }
    } catch (_) {}
    return null;
  }

  void _fitMap() {
    final loc = _location;
    if (loc == null || !loc.hasLocation) return;
    final busPos = LatLng(loc.currentLatitude!, loc.currentLongitude!);
    final dest = _destinationLatLng;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (dest != null) {
        final bounds = LatLngBounds(busPos, dest);
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
        );
      } else {
        _mapController.move(busPos, 13);
      }
    });
  }

  String _statusLabel(String status) => switch (status) {
        'scheduled' => 'Scheduled',
        'boarding' => 'Boarding',
        'in_progress' => 'In Progress',
        'halted' => 'Halted',
        'completed' => 'Completed',
        'cancelled' => 'Cancelled',
        _ => status,
      };

  Color _statusColor(String status) => switch (status) {
        'scheduled' => Colors.blue,
        'boarding' => Colors.orange,
        'in_progress' => Colors.green,
        'halted' => Colors.deepOrange,
        'completed' => Colors.grey,
        'cancelled' => Colors.red,
        _ => Colors.blueGrey,
      };

  String _fmtTime(DateTime dt) {
    final h = dt.toLocal().hour % 12 == 0 ? 12 : dt.toLocal().hour % 12;
    final m = dt.toLocal().minute.toString().padLeft(2, '0');
    final ap = dt.toLocal().hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = _location;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live Bus Tracking',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            if (loc != null)
              Text('${loc.origin} → ${loc.destination}',
                  style: tt.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.darkOnSurfaceVariant
                          : AppColors.lightOnSurfaceVariant)),
          ],
        ),
        actions: [
          if (loc != null)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(loc.status).withValues(alpha:0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _statusLabel(loc.status),
                style: tt.labelSmall?.copyWith(
                  color: _statusColor(loc.status),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && loc == null
              ? _buildError(tt)
              : Column(
                  children: [
                    Expanded(child: _buildMap(loc)),
                    _buildInfoCard(loc, tt, isDark),
                  ],
                ),
    );
  }

  Widget _buildError(TextTheme tt) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_off_rounded, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(_error!, style: tt.bodyMedium),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() { _isLoading = true; _error = null; });
              _fetchAndUpdate();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(TripLiveLocation? loc) {
    final busPos = (loc != null && loc.hasLocation)
        ? LatLng(loc.currentLatitude!, loc.currentLongitude!)
        : null;
    final destPos = _destinationLatLng;

    final initialCenter = busPos ?? destPos ?? const LatLng(5.6037, -0.1870);

    return RepaintBoundary(
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: initialCenter,
          initialZoom: 13,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.bus_ticketing',
          ),
          if (busPos != null && destPos != null)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: [busPos, destPos],
                  strokeWidth: 3.5,
                  color: AppColors.primary.withValues(alpha:0.8),
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              if (busPos != null)
                Marker(
                  point: busPos,
                  width: 48,
                  height: 48,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha:0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: const Icon(Icons.directions_bus_rounded,
                        color: Colors.white, size: 26),
                  ),
                ),
              if (destPos != null)
                Marker(
                  point: destPos,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_pin,
                      color: Colors.red, size: 40),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(TripLiveLocation? loc, TextTheme tt, bool isDark) {
    final card = isDark ? AppColors.darkSurface : AppColors.white;
    final subtle = isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant;

    return Container(
      color: card,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loc != null && loc.status == 'halted') ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.deepOrange.withValues(alpha:0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.pause_circle_outline_rounded,
                    color: Colors.deepOrange, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Trip temporarily halted — showing last known position.',
                    style: tt.bodySmall?.copyWith(
                        color: Colors.deepOrange, fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
          ],
          if (loc == null || !loc.hasLocation)
            Row(children: [
              const Icon(Icons.location_searching_rounded,
                  size: 16, color: AppColors.grey400),
              const SizedBox(width: 8),
              Text('Bus location not yet available',
                  style: tt.bodySmall?.copyWith(color: AppColors.grey400)),
            ])
          else ...[
            Row(children: [
              const Icon(Icons.directions_bus_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${loc.busModel}  ·  ${loc.busPlate}',
                  style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.access_time_rounded,
                      size: 14, color: AppColors.grey500),
                  const SizedBox(width: 4),
                  Text('Departs ${_fmtTime(loc.departureTime)}',
                      style: tt.bodySmall?.copyWith(color: subtle)),
                ]),
                if (_lastUpdated != null)
                  Row(children: [
                    Icon(Icons.sync_rounded, size: 12, color: AppColors.success),
                    const SizedBox(width: 3),
                    Text(
                      'Updated ${_fmtTime(_lastUpdated!)}',
                      style: tt.bodySmall?.copyWith(
                          color: AppColors.success, fontSize: 11),
                    ),
                  ]),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text('Updates every 10 seconds',
              style: tt.bodySmall?.copyWith(
                  color: AppColors.grey400, fontSize: 11)),
        ],
      ),
    );
  }
}
