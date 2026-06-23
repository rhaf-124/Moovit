import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/repositories/trip_repository.dart';
import '../models/bus_model.dart';
import '../models/bus_search_params.dart';
import '../models/trip_response_mapper.dart';

class BusResultsPage extends StatefulWidget {
  final BusSearchParams params;
  const BusResultsPage({super.key, required this.params});

  @override
  State<BusResultsPage> createState() => _BusResultsPageState();
}

enum _SortOption { priceAsc, priceDesc, departureAsc, departureDesc }

class _BusResultsPageState extends State<BusResultsPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<BusModel> _buses = [];
  List<BusModel> _filteredBuses = [];

  _SortOption _sortOption = _SortOption.departureAsc;
  Set<String> _amenityFilters = {};

  void _applyFiltersAndSort() {
    List<BusModel> result = List.from(_buses);

    if (_amenityFilters.isNotEmpty) {
      result = result
          .where((b) => _amenityFilters.every((a) => b.amenities.contains(a)))
          .toList();
    }

    switch (_sortOption) {
      case _SortOption.priceAsc:
        result.sort((a, b) => a.pricePerSeat.compareTo(b.pricePerSeat));
      case _SortOption.priceDesc:
        result.sort((a, b) => b.pricePerSeat.compareTo(a.pricePerSeat));
      case _SortOption.departureAsc:
        result.sort((a, b) => a.departureTime.compareTo(b.departureTime));
      case _SortOption.departureDesc:
        result.sort((a, b) => b.departureTime.compareTo(a.departureTime));
    }

    setState(() => _filteredBuses = result);
  }

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final repo = RepositoryProvider.of<TripRepository>(context);
      
      // Format date as YYYY-MM-DD
      final year = widget.params.date.year;
      final month = widget.params.date.month.toString().padLeft(2, '0');
      final day = widget.params.date.day.toString().padLeft(2, '0');
      final dateStr = '$year-$month-$day';

      final trips = await repo.searchTrips(
        origin: widget.params.from,
        destination: widget.params.to,
        date: dateStr,
      );

      if (mounted) {
        final now = DateTime.now();
        setState(() {
          _buses = trips
              .where((t) =>
                  t.status == 'scheduled' &&
                  t.availableSeats > 0 &&
                  t.departureTime.isAfter(now))
              .map((t) => t.toBusModel())
              .toList();
          _isLoading = false;
        });
        _applyFiltersAndSort();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.params.from} → ${widget.params.to}',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              _fmtDate(widget.params.date),
              style: tt.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.darkOnSurfaceVariant
                    : AppColors.lightOnSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? _buildLoading(tt, cs)
          : _errorMessage != null
              ? _buildError(tt, cs)
              : _buildResults(tt, cs, isDark),
    );
  }

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
                color: AppColors.error.withValues(alpha:0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load trips',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'An unexpected error occurred',
              style: tt.bodySmall?.copyWith(color: AppColors.grey500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadTrips,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Loading ─────────────────────────────────────────────────────────────────

  Widget _buildLoading(TextTheme tt, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _topBar(tt, cs, count: 0, enabled: false),

        const Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Searching for buses...'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Results ─────────────────────────────────────────────────────────────────

  Widget _buildResults(TextTheme tt, ColorScheme cs, bool isDark) {
    return Column(
      children: [
        _topBar(tt, cs, count: _filteredBuses.length, enabled: _buses.isNotEmpty),
        Expanded(
          child: _filteredBuses.isEmpty
              ? _buildEmpty(tt)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: _filteredBuses.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _BusCard(
                    bus: _filteredBuses[i],
                    fromCity: widget.params.from,
                    toCity: widget.params.to,
                    isDark: isDark,
                    tt: tt,
                    cs: cs,
                    onSelectSeats: () => context.push(
                      AppRoutes.seatSelection,
                      extra: {'bus': _filteredBuses[i], 'params': widget.params},
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmpty(TextTheme tt) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/empty.jpg',
              width: 220,
              errorBuilder: (_, _, _) => const Icon(
                Icons.directions_bus_rounded,
                size: 80,
                color: AppColors.grey300,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No search results',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Sorry, no buses were found for this route and date. Try a different date or route.',
              style: tt.bodySmall?.copyWith(color: AppColors.grey500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Change Search'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(
    TextTheme tt,
    ColorScheme cs, {
    required int count,
    required bool enabled,
  }) {
    final hasFilters = _amenityFilters.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              '$count ${count == 1 ? 'bus' : 'buses'} found',
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _actionChip(
                label: 'Sort',
                icon: Icons.sort_rounded,
                enabled: enabled,
                active: false,
                cs: cs,
                tt: tt,
                onTap: _showSortSheet,
              ),
              const SizedBox(width: 8),
              _actionChip(
                label: 'Filters',
                icon: Icons.tune_rounded,
                enabled: enabled,
                active: hasFilters,
                cs: cs,
                tt: tt,
                onTap: _showFilterSheet,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionChip({
    required String label,
    required IconData icon,
    required bool enabled,
    required bool active,
    required ColorScheme cs,
    required TextTheme tt,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 15),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: tt.labelMedium,
        foregroundColor: active ? cs.primary : null,
        side: active ? BorderSide(color: cs.primary) : null,
      ),
    );
  }

  void _showSortSheet() {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final options = [
      (_SortOption.departureAsc, 'Departure: Earliest First', Icons.schedule_rounded),
      (_SortOption.departureDesc, 'Departure: Latest First', Icons.schedule_rounded),
      (_SortOption.priceAsc, 'Price: Low to High', Icons.arrow_upward_rounded),
      (_SortOption.priceDesc, 'Price: High to Low', Icons.arrow_downward_rounded),
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Sort By', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              RadioGroup<_SortOption>(
                groupValue: _sortOption,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _sortOption = v);
                  setLocal(() {});
                  _applyFiltersAndSort();
                  Navigator.pop(ctx);
                },
                child: Column(
                  children: options.map((o) {
                    final (opt, label, icon) = o;
                    final selected = _sortOption == opt;
                    return RadioListTile<_SortOption>(
                      value: opt,
                      title: Row(
                        children: [
                          Icon(icon, size: 18, color: selected ? cs.primary : cs.onSurface),
                          const SizedBox(width: 8),
                          Text(label, style: tt.bodyMedium),
                        ],
                      ),
                      contentPadding: EdgeInsets.zero,
                      fillColor: WidgetStateProperty.resolveWith((states) =>
                          states.contains(WidgetState.selected) ? cs.primary : null),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterSheet() {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    const amenities = [
      ('wifi', 'WiFi', Icons.wifi_rounded),
      ('ac', 'Air Conditioning', Icons.ac_unit_rounded),
      ('food', 'Food & Drinks', Icons.restaurant_rounded),
      ('charging', 'USB Charging', Icons.bolt_rounded),
    ];

    final tempFilters = Set<String>.from(_amenityFilters);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filters', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  if (tempFilters.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        tempFilters.clear();
                        setLocal(() {});
                      },
                      child: const Text('Clear All'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Amenities', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 8),
              ...amenities.map((a) {
                final (key, label, icon) = a;
                final checked = tempFilters.contains(key);
                return CheckboxListTile(
                  value: checked,
                  title: Row(
                    children: [
                      Icon(icon, size: 18, color: checked ? cs.primary : cs.onSurface),
                      const SizedBox(width: 8),
                      Text(label, style: tt.bodyMedium),
                    ],
                  ),
                  contentPadding: EdgeInsets.zero,
                  checkColor: cs.onPrimary,
                  fillColor: WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.selected) ? cs.primary : null),
                  onChanged: (v) {
                    setLocal(() {
                      if (v == true) {
                        tempFilters.add(key);
                      } else {
                        tempFilters.remove(key);
                      }
                    });
                  },
                );
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _amenityFilters = Set.from(tempFilters));
                    _applyFiltersAndSort();
                    Navigator.pop(ctx);
                  },
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bus Card ──────────────────────────────────────────────────────────────────

class _BusCard extends StatelessWidget {
  const _BusCard({
    required this.bus,
    required this.fromCity,
    required this.toCity,
    required this.isDark,
    required this.tt,
    required this.cs,
    required this.onSelectSeats,
  });

  final BusModel bus;
  final String fromCity;
  final String toCity;
  final bool isDark;
  final TextTheme tt;
  final ColorScheme cs;
  final VoidCallback onSelectSeats;

  String _resolveImageUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return rawUrl;
    if (uri.isAbsolute) return rawUrl;
    final base = ApiConstants.baseUrl.replaceAll(RegExp(r'/$'), '');
    return '$base${uri.path}';
  }

  Widget _buildFallbackBusImage(bool isDark) {
    return Image.asset(
      'assets/images/bus_image.png',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: isDark ? AppColors.grey800 : Colors.indigo.shade50,
        child: Icon(
          Icons.directions_bus_rounded,
          color: isDark ? AppColors.grey400 : Colors.indigo,
          size: 30,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = isDark ? AppColors.darkSurface : AppColors.white;
    final border = isDark ? AppColors.darkOutline : AppColors.lightOutline;
    final subtle = isDark
        ? AppColors.darkOnSurfaceVariant
        : AppColors.lightOnSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + rating + Image
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Bus image
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 80,
                  height: 60,
                  child: bus.imageUrl != null && bus.imageUrl!.isNotEmpty
                      ? Image.network(
                          _resolveImageUrl(bus.imageUrl!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _buildFallbackBusImage(isDark),
                        )
                      : _buildFallbackBusImage(isDark),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bus.name,
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      bus.busNumber,
                      style: tt.bodySmall?.copyWith(color: AppColors.grey400),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star_rounded,
                      size: 16, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 4),
                  Text(
                    bus.rating.toStringAsFixed(1),
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Times
          Row(
            children: [
              Text(
                bus.departureTime,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      Text(
                        bus.duration,
                        style: tt.bodySmall?.copyWith(color: AppColors.grey400),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(height: 1, color: border),
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Divider(height: 1, color: border),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${bus.distanceKm} km',
                        style: tt.bodySmall?.copyWith(color: AppColors.grey400),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                bus.arrivalTime,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Cities
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(fromCity, style: tt.bodySmall?.copyWith(color: subtle)),
              Text(toCity, style: tt.bodySmall?.copyWith(color: subtle)),
            ],
          ),
          const SizedBox(height: 12),

          // Tags + amenities
          Row(
            children: [
              ...bus.tags.map(
                (tag) => Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tag,
                    style: tt.labelSmall?.copyWith(color: cs.primary),
                  ),
                ),
              ),
              Text(
                '${bus.availableSeats} seats left',
                style: tt.bodySmall?.copyWith(color: AppColors.grey500),
              ),
              const Spacer(),
              ...bus.amenities.take(4).map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(
                        _amenityIcon(a),
                        size: 16,
                        color: AppColors.grey400,
                      ),
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: border),
          const SizedBox(height: 12),

          // Price + button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Starting from',
                    style: tt.bodySmall?.copyWith(color: subtle),
                  ),
                  Text(
                    'GH₵${bus.pricePerSeat.toStringAsFixed(2)}',
                    style: tt.titleMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: onSelectSeats,
                child: const Text('Select Seats'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _amenityIcon(String a) => switch (a) {
        'wifi' => Icons.wifi_rounded,
        'ac' => Icons.ac_unit_rounded,
        'food' => Icons.restaurant_rounded,
        'charging' => Icons.bolt_rounded,
        _ => Icons.check_rounded,
      };
}
