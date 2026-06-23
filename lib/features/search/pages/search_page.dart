import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../bus_search/domain/repositories/trip_repository.dart';
import '../../bus_search/models/bus_search_params.dart';
import '../../bus_search/models/trip_response.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  String _query = '';

  List<TripResponse> _allTrips = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTrips());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadTrips() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = RepositoryProvider.of<TripRepository>(context);
      final trips = await repo.searchTrips();
      if (mounted) {
        final now = DateTime.now();
        setState(() => _allTrips = trips
            .where((t) =>
                t.status == 'scheduled' &&
                t.availableSeats > 0 &&
                t.departureTime.isAfter(now))
            .toList());
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<TripResponse> get _filtered {
    if (_query.isEmpty) return _allTrips;
    final q = _query.toLowerCase();
    return _allTrips.where((t) {
      return t.origin.toLowerCase().contains(q) ||
          t.destination.toLowerCase().contains(q);
    }).toList();
  }

  List<String> get _popularRoutes {
    final seen = <String>{};
    final routes = <String>[];
    for (final t in _allTrips) {
      final key = '${t.origin} → ${t.destination}';
      if (seen.add(key)) routes.add(key);
      if (routes.length >= 4) break;
    }
    return routes;
  }

  void _onTripTap(TripResponse trip) {
    context.push(
      AppRoutes.busResults,
      extra: BusSearchParams(
        from: trip.origin,
        to: trip.destination,
        date: trip.departureTime,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Search Routes',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _controller,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search city or route…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? _SkeletonList(isDark: isDark)
          : _error != null
              ? _ErrorState(onRetry: _loadTrips, tt: tt, cs: cs)
              : _query.isEmpty
                  ? _Discovery(
                      trips: _allTrips,
                      popularRoutes: _popularRoutes,
                      isDark: isDark,
                      tt: tt,
                      cs: cs,
                      onTap: _onTripTap,
                      onPopularTap: (route) {
                        final parts = route.split(' → ');
                        _controller.text = parts.first;
                        setState(() => _query = parts.first);
                      },
                      onRefresh: _loadTrips,
                    )
                  : _Results(
                      trips: _filtered,
                      isDark: isDark,
                      tt: tt,
                      cs: cs,
                      onTap: _onTripTap,
                    ),
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _SkeletonList extends StatelessWidget {
  const _SkeletonList({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.grey800 : AppColors.grey200,
      highlightColor: isDark ? AppColors.grey700 : AppColors.grey100,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) => Container(
          height: 76,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry, required this.tt, required this.cs});
  final VoidCallback onRetry;
  final TextTheme tt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha:0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  color: AppColors.error, size: 40),
            ),
            const SizedBox(height: 16),
            Text('Could not load routes',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Check your connection and try again.',
                style: tt.bodySmall?.copyWith(color: AppColors.grey500),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Discovery (no query) ──────────────────────────────────────────────────────

class _Discovery extends StatelessWidget {
  const _Discovery({
    required this.trips,
    required this.popularRoutes,
    required this.isDark,
    required this.tt,
    required this.cs,
    required this.onTap,
    required this.onPopularTap,
    required this.onRefresh,
  });

  final List<TripResponse> trips;
  final List<String> popularRoutes;
  final bool isDark;
  final TextTheme tt;
  final ColorScheme cs;
  final void Function(TripResponse) onTap;
  final void Function(String) onPopularTap;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (popularRoutes.isNotEmpty) ...[
            _SectionLabel(label: 'Popular Routes', tt: tt),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: popularRoutes.map((r) {
                return ActionChip(
                  label: Text(r),
                  labelStyle: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  avatar: Icon(Icons.trending_up_rounded,
                      size: 16, color: cs.primary),
                  onPressed: () => onPopularTap(r),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
          ],
          _SectionLabel(
            label: 'All Available Trips (${trips.length})',
            tt: tt,
          ),
          const SizedBox(height: 12),
          if (trips.isEmpty)
            _EmptyTrips(isDark: isDark, tt: tt)
          else
            ...trips.map((t) => _TripTile(
                  trip: t,
                  isDark: isDark,
                  tt: tt,
                  cs: cs,
                  onTap: () => onTap(t),
                )),
        ],
      ),
    );
  }
}

// ── Results (with query) ──────────────────────────────────────────────────────

class _Results extends StatelessWidget {
  const _Results({
    required this.trips,
    required this.isDark,
    required this.tt,
    required this.cs,
    required this.onTap,
  });

  final List<TripResponse> trips;
  final bool isDark;
  final TextTheme tt;
  final ColorScheme cs;
  final void Function(TripResponse) onTap;

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/empty.jpg',
              width: 200,
              errorBuilder: (_, _, _) => Icon(
                Icons.search_off_rounded,
                size: 72,
                color: isDark ? AppColors.grey700 : AppColors.grey300,
              ),
            ),
            const SizedBox(height: 20),
            Text('No routes found',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Try a different city name.',
                style: tt.bodySmall?.copyWith(color: AppColors.grey500)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: trips.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _TripTile(
        trip: trips[i],
        isDark: isDark,
        tt: tt,
        cs: cs,
        onTap: () => onTap(trips[i]),
      ),
    );
  }
}

class _EmptyTrips extends StatelessWidget {
  const _EmptyTrips({required this.isDark, required this.tt});
  final bool isDark;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_bus_outlined,
                size: 56,
                color: isDark ? AppColors.grey700 : AppColors.grey300),
            const SizedBox(height: 12),
            Text('No trips available right now.',
                style: tt.bodyMedium
                    ?.copyWith(color: isDark ? AppColors.grey500 : AppColors.grey400)),
          ],
        ),
      ),
    );
  }
}

// ── Trip tile ─────────────────────────────────────────────────────────────────

class _TripTile extends StatelessWidget {
  const _TripTile({
    required this.trip,
    required this.isDark,
    required this.tt,
    required this.cs,
    required this.onTap,
  });

  final TripResponse trip;
  final bool isDark;
  final TextTheme tt;
  final ColorScheme cs;
  final VoidCallback onTap;

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _fmtDate(DateTime dt) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final card = isDark ? AppColors.darkSurface : AppColors.white;
    final border = isDark ? AppColors.darkOutline : AppColors.lightOutline;
    final subtle = isDark
        ? AppColors.darkOnSurfaceVariant
        : AppColors.lightOnSurfaceVariant;

    final seatsLow = trip.availableSeats <= 5 && trip.availableSeats > 0;
    final full = trip.availableSeats == 0;

    return GestureDetector(
      onTap: full ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha:0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Bus icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.directions_bus_rounded,
                  color: cs.primary, size: 22),
            ),
            const SizedBox(width: 14),
            // Route info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${trip.origin} → ${trip.destination}',
                    style:
                        tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 12, color: subtle),
                      const SizedBox(width: 4),
                      Text(
                        '${_fmtDate(trip.departureTime)}  ${_fmtTime(trip.departureTime)}',
                        style: tt.bodySmall?.copyWith(color: subtle),
                      ),
                      const SizedBox(width: 10),
                      if (full)
                        _Chip(label: 'Full', color: AppColors.error)
                      else if (seatsLow)
                        _Chip(
                          label: '${trip.availableSeats} left',
                          color: const Color(0xFFF59E0B),
                        )
                      else
                        Text(
                          '${trip.availableSeats} seats',
                          style: tt.bodySmall?.copyWith(color: subtle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    trip.busModel,
                    style: tt.bodySmall?.copyWith(color: subtle),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'GH₵${trip.fare.toStringAsFixed(0)}',
                  style: tt.titleSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: subtle),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.tt});
  final String label;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: tt.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.grey500,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
