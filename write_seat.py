#!/usr/bin/env python3
"""Script to generate the booking system Flutter files."""
import os

BASE = r"lib\features\bus_search"


def w(path, content):
    full = os.path.join(BASE, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Written: {full}")


# ── SeatSelectionPage ─────────────────────────────────────────────────────────

SEAT_SELECTION = r"""import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/repositories/booking_repository.dart';
import '../domain/repositories/trip_repository.dart';
import '../models/booking_data.dart';
import '../models/bus_model.dart';
import '../models/bus_search_params.dart';

enum _SeatDisplay { available, selected, reserved, booked }

class _SeatCell {
  final String id;
  final int number;
  _SeatDisplay display;
  SeatGender? gender;
  bool hasLuggage;
  String luggageType;
  _SeatCell(this.id, this.number, this.display,
      [this.gender, this.hasLuggage = false, this.luggageType = 'none']);
}

class SeatSelectionPage extends StatefulWidget {
  final BusModel bus;
  final BusSearchParams params;
  const SeatSelectionPage({super.key, required this.bus, required this.params});
  @override
  State<SeatSelectionPage> createState() => _SeatSelectionPageState();
}

class _SeatSelectionPageState extends State<SeatSelectionPage>
    with TickerProviderStateMixin {
  static const int _maxSeats = 12;
  late BusModel _bus;
  List<_SeatCell> _grid = [];
  bool _showLegend = true;
  bool _isLoadingSeats = true;
  bool _isBooking = false;
  String? _seatsError;
  DateTime? _expiresAt;
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _bus = widget.bus;
    _fetchSeats();
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _pulseAnimation =
        Tween<double>(begin: 0.85, end: 1.0).animate(_pulseController);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchSeats() async {
    setState(() {
      _isLoadingSeats = true;
      _seatsError = null;
    });
    try {
      final repo = RepositoryProvider.of<TripRepository>(context);
      final seats = await repo.getTripSeats(_bus.id);
      if (mounted) {
        setState(() {
          _grid = seats.asMap().entries.map((entry) {
            final s = entry.value;
            final number = int.tryParse(s.seatNumber) ?? (entry.key + 1);
            if (s.isEffectivelyUnavailable) {
              return _SeatCell(s.id, number,
                  s.status == 'reserved' ? _SeatDisplay.reserved : _SeatDisplay.booked);
            }
            return _SeatCell(s.id, number, _SeatDisplay.available);
          }).toList()
            ..sort((a, b) => a.number.compareTo(b.number));
          _bus = _bus.copyWith(totalSeats: seats.length, prePopulatedSeats: []);
          _isLoadingSeats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _grid = List.generate(_bus.totalSeats,
              (i) => _SeatCell('seat-${i + 1}', i + 1, _SeatDisplay.available));
          _seatsError = e.toString();
          _isLoadingSeats = false;
        });
      }
    }
  }

  void _startCountdown(DateTime expiresAt) {
    _expiresAt = expiresAt;
    _countdownTimer?.cancel();
    _updateRemaining();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _updateRemaining();
      if (_remaining == Duration.zero) {
        _countdownTimer?.cancel();
        _showExpiredDialog();
      }
    });
  }

  void _updateRemaining() {
    if (_expiresAt == null) return;
    final diff = _expiresAt!.difference(DateTime.now().toUtc());
    setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
  }

  void _showExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Hold Expired'),
        content: const Text('Your seat hold has expired. Please search again.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go(AppRoutes.home);
            },
            child: const Text('Back to Search'),
          ),
        ],
      ),
    );
  }

  String _formatCountdown(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '${h}h ${m}m ${s}s';
    return '$m:$s';
  }

  List<_SeatCell> get _selected =>
      _grid.where((s) => s.display == _SeatDisplay.selected).toList();

  Future<void> _onSeatTap(_SeatCell seat) async {
    if (seat.display == _SeatDisplay.selected) {
      setState(() {
        seat.display = _SeatDisplay.available;
        seat.gender = null;
        seat.hasLuggage = false;
        seat.luggageType = 'none';
      });
      return;
    }
    if (seat.display != _SeatDisplay.available) return;
    if (_selected.length >= _maxSeats) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Maximum $_maxSeats seats can be selected'),
          behavior: SnackBarBehavior.floating));
      return;
    }
    final result = await showModalBottomSheet<_SeatDetails>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SeatDetailsSheet(seatNumber: seat.number),
    );
    if (result != null && mounted) {
      setState(() {
        seat.display = _SeatDisplay.selected;
        seat.gender = result.gender;
        seat.hasLuggage = result.hasLuggage;
        seat.luggageType = result.luggageType;
      });
    }
  }

  String _genderStr(SeatGender g) =>
      g == SeatGender.male ? 'male' : g == SeatGender.female ? 'female' : 'other';

  Future<void> _onContinue() async {
    final sel = _selected;
    if (sel.isEmpty) return;
    setState(() => _isBooking = true);
    try {
      final repo = RepositoryProvider.of<BookingRepository>(context);
      final payload = sel
          .map((s) => {
                'seat_id': s.id,
                'gender': _genderStr(s.gender ?? SeatGender.other),
                'has_luggage': s.hasLuggage,
                'luggage_type': s.luggageType,
              })
          .toList();
      final booking = await repo.createBooking(tripId: _bus.id, seats: payload);
      if (!mounted) return;
      _startCountdown(booking.expiresAt);
      final data = BookingData(
        bus: _bus,
        fromCity: widget.params.from,
        toCity: widget.params.to,
        date: widget.params.date,
        selectedSeats: sel
            .map((s) => SelectedSeat(
                  seatId: s.id,
                  seatNumber: s.number,
                  gender: s.gender ?? SeatGender.other,
                  hasLuggage: s.hasLuggage,
                  luggageType: s.luggageType,
                ))
            .toList(),
        bookingResponse: booking,
      );
      context.push(AppRoutes.payment, extra: data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Booking failed: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sel = _selected;
    final isWarning = _expiresAt != null && _remaining.inMinutes < 5;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop()),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Select Seats',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          Text('Select up to $_maxSeats seats',
              style: tt.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.darkOnSurfaceVariant
                      : AppColors.lightOnSurfaceVariant)),
        ]),
        actions: [
          if (_expiresAt != null)
            ScaleTransition(
              scale: isWarning
                  ? _pulseAnimation
                  : const AlwaysStoppedAnimation(1.0),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isWarning
                      ? AppColors.error.withOpacity(0.15)
                      : cs.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isWarning ? AppColors.error : cs.primary),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.timer_rounded,
                      size: 14,
                      color: isWarning ? AppColors.error : cs.primary),
                  const SizedBox(width: 4),
                  Text(_formatCountdown(_remaining),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isWarning ? AppColors.error : cs.primary)),
                ]),
              ),
            ),
          IconButton(
            icon: Icon(_showLegend
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded),
            onPressed: () => setState(() => _showLegend = !_showLegend),
          ),
        ],
      ),
      body: Stack(children: [
        Column(children: [
          if (_seatsError != null)
            Material(
              color: Colors.orange.shade700,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                      child: Text(
                          'Could not refresh seats — showing cached layout',
                          style: TextStyle(color: Colors.white, fontSize: 12))),
                  GestureDetector(
                    onTap: _fetchSeats,
                    child: const Text('Retry',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline)),
                  ),
                ]),
              ),
            ),
          Expanded(
            child: _isLoadingSeats
                ? _buildShimmer(isDark)
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBusInfo(tt, cs, isDark),
                          if (_showLegend) ...[
                            const SizedBox(height: 16),
                            _buildLegend(tt, isDark),
                          ],
                          const SizedBox(height: 20),
                          _buildDriverRow(cs),
                          const SizedBox(height: 12),
                          _buildSeatGrid(tt, cs, isDark),
                          const SizedBox(height: 80),
                        ]),
                  ),
          ),
          _buildBottomPanel(tt, cs, isDark, sel),
        ]),
        if (_isBooking)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text('Reserving your seats...',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _buildShimmer(bool isDark) {
    final base = isDark ? AppColors.grey800 : const Color(0xFFE5E7EB);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Container(
            height: 80,
            decoration: BoxDecoration(
                color: base, borderRadius: BorderRadius.circular(12))),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: List.generate(
              20,
              (_) => Container(
                  decoration: BoxDecoration(
                      color: base, borderRadius: BorderRadius.circular(8)))),
        ),
      ]),
    );
  }

  String _resolveImageUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return raw;
    final base = ApiConstants.baseUrl.replaceAll(RegExp(r'/$'), '');
    return '$base${uri.path}';
  }

  Widget _buildFallbackBusImage(bool isDark) => Container(
        color: isDark ? AppColors.grey800 : Colors.indigo.shade50,
        child: Icon(Icons.directions_bus_rounded,
            color: isDark ? AppColors.grey400 : Colors.indigo, size: 28),
      );

  Widget _buildBusInfo(TextTheme tt, ColorScheme cs, bool isDark) {
    final card = isDark ? AppColors.darkSurface : AppColors.white;
    final border = isDark ? AppColors.darkOutline : AppColors.lightOutline;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border)),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 64,
            height: 48,
            child: _bus.imageUrl != null && _bus.imageUrl!.isNotEmpty
                ? Image.network(_resolveImageUrl(_bus.imageUrl!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildFallbackBusImage(isDark))
                : _buildFallbackBusImage(isDark),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_bus.name,
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('${widget.params.from} → ${widget.params.to}',
              style: tt.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.darkOnSurfaceVariant
                      : AppColors.lightOnSurfaceVariant)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_bus.departureTime,
              style: tt.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700, color: cs.primary)),
          Text(_bus.busNumber,
              style: tt.bodySmall?.copyWith(color: AppColors.grey400)),
        ]),
      ]),
    );
  }

  Widget _buildLegend(TextTheme tt, bool isDark) {
    return Wrap(spacing: 16, runSpacing: 8, children: [
      _legendItem(
          color: isDark ? AppColors.darkSurface : AppColors.white,
          borderColor: isDark ? AppColors.darkOutline : AppColors.lightOutline,
          label: 'Available', tt: tt),
      _legendItem(color: AppColors.primary, label: 'Selected', tt: tt),
      _legendItem(color: AppColors.grey300, label: 'Reserved', tt: tt),
      _legendItem(color: AppColors.error, label: 'Booked', tt: tt),
    ]);
  }

  Widget _legendItem({required Color color, Color? borderColor,
      required String label, required TextTheme tt}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 20, height: 20,
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: borderColor != null ? Border.all(color: borderColor) : null)),
      const SizedBox(width: 6),
      Text(label, style: tt.bodySmall),
    ]);
  }

  Widget _buildDriverRow(ColorScheme cs) {
    return Row(children: [
      Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8)),
        alignment: Alignment.center,
        child: Row(children: [
          Icon(Icons.directions_bus_rounded, color: cs.primary, size: 18),
          const SizedBox(width: 6),
          Text('Driver',
              style: TextStyle(
                  color: cs.primary, fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      ),
      const Spacer(),
      Container(
          width: 48, height: 36,
          decoration: BoxDecoration(
              color: cs.primary, borderRadius: BorderRadius.circular(8))),
    ]);
  }

  Widget _buildSeatGrid(TextTheme tt, ColorScheme cs, bool isDark) {
    final rowCount = (_grid.length / 4).ceil();
    return Column(
      children: List.generate(rowCount, (row) {
        final indices = [row * 4, row * 4 + 1, row * 4 + 2, row * 4 + 3]
            .where((i) => i < _grid.length)
            .toList();
        Widget cell(int idx) => _buildSeatCell(_grid[idx], tt, cs, isDark);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            if (indices.isNotEmpty) Expanded(child: cell(indices[0])),
            const SizedBox(width: 6),
            indices.length > 1
                ? Expanded(child: cell(indices[1]))
                : const Expanded(child: SizedBox()),
            const SizedBox(width: 14),
            indices.length > 2
                ? Expanded(child: cell(indices[2]))
                : const Expanded(child: SizedBox()),
            const SizedBox(width: 6),
            indices.length > 3
                ? Expanded(child: cell(indices[3]))
                : const Expanded(child: SizedBox()),
          ]),
        );
      }),
    );
  }

  Widget _buildSeatCell(
      _SeatCell seat, TextTheme tt, ColorScheme cs, bool isDark) {
    final (bg, fg, icon) = _seatStyle(seat, cs, isDark);
    final interactive = seat.display == _SeatDisplay.available ||
        seat.display == _SeatDisplay.selected;
    return GestureDetector(
      onTap: interactive ? () => _onSeatTap(seat) : null,
      child: AspectRatio(
        aspectRatio: 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: seat.display == _SeatDisplay.available
                ? Border.all(
                    color: isDark ? AppColors.darkOutline : AppColors.grey300)
                : null,
            boxShadow: seat.display == _SeatDisplay.selected
                ? [BoxShadow(color: cs.primary.withOpacity(0.3), blurRadius: 8)]
                : null,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) Icon(icon, size: 13, color: fg),
            Text('${seat.number}',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
            if (seat.hasLuggage && seat.display == _SeatDisplay.selected)
              Icon(Icons.luggage_rounded, size: 9, color: fg),
          ]),
        ),
      ),
    );
  }

  (Color, Color, IconData?) _seatStyle(
      _SeatCell seat, ColorScheme cs, bool isDark) {
    final onSurface =
        isDark ? AppColors.darkOnSurface : AppColors.lightOnSurface;
    final surface = isDark ? AppColors.darkSurface : AppColors.white;
    return switch (seat.display) {
      _SeatDisplay.available => (surface, onSurface, null),
      _SeatDisplay.selected =>
        (cs.primary, Colors.white, Icons.person_rounded),
      _SeatDisplay.reserved => (AppColors.grey300, AppColors.grey500, null),
      _SeatDisplay.booked =>
        (AppColors.error, Colors.white, Icons.block_rounded),
    };
  }

  Widget _buildBottomPanel(
      TextTheme tt, ColorScheme cs, bool isDark, List<_SeatCell> sel) {
    final bg = isDark ? AppColors.darkSurface : AppColors.white;
    final border = isDark ? AppColors.darkOutline : AppColors.lightOutline;
    final subtle =
        isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant;
    if (sel.isEmpty) {
      return Container(
        decoration:
            BoxDecoration(color: bg, border: Border(top: BorderSide(color: border))),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
                onPressed: null,
                child: const Text('Select Seats to Continue'))),
      );
    }
    final price = sel.length * _bus.pricePerSeat;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -4))
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 18),
            const SizedBox(width: 8),
            Text('Seats: ${sel.map((s) => s.number).join(', ')}',
                style: tt.bodySmall?.copyWith(
                    color: AppColors.success, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${sel.length} selected',
                style: tt.bodySmall?.copyWith(color: subtle)),
          ]),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Estimated Total:',
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
          Text('\$${price.toStringAsFixed(2)}',
              style: tt.titleSmall?.copyWith(
                  color: cs.primary, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isBooking ? null : _onContinue,
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            child: _isBooking
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(
                    'Reserve ${sel.length} Seat${sel.length > 1 ? "s" : ""} · \$${price.toStringAsFixed(2)}'),
          ),
        ),
      ]),
    );
  }
}

// ── Seat details data ─────────────────────────────────────────────────────────

class _SeatDetails {
  final SeatGender gender;
  final bool hasLuggage;
  final String luggageType;
  const _SeatDetails(
      {required this.gender, required this.hasLuggage, required this.luggageType});
}

// ── Seat Details bottom sheet ─────────────────────────────────────────────────

class _SeatDetailsSheet extends StatefulWidget {
  final int seatNumber;
  const _SeatDetailsSheet({required this.seatNumber});
  @override
  State<_SeatDetailsSheet> createState() => _SeatDetailsSheetState();
}

class _SeatDetailsSheetState extends State<_SeatDetailsSheet> {
  SeatGender _gender = SeatGender.male;
  bool _hasLuggage = false;
  String _luggageType = 'backpack';

  static const _genderOpts = [
    (SeatGender.male, 'Male', Icons.male_rounded, Color(0xFF4B7BF5)),
    (SeatGender.female, 'Female', Icons.female_rounded, Color(0xFFEC4899)),
    (SeatGender.other, 'Other', Icons.person_rounded, Color(0xFF8B5CF6)),
  ];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : AppColors.white;
    final border = isDark ? AppColors.darkOutline : AppColors.lightOutline;

    return Container(
      decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: isDark ? AppColors.darkOutline : AppColors.grey300,
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 20),
        Text('Seat ${widget.seatNumber} Details',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Choose gender & luggage preference',
            style: tt.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.darkOnSurfaceVariant
                    : AppColors.lightOnSurfaceVariant),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        Align(
            alignment: Alignment.centerLeft,
            child: Text('Passenger Gender',
                style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700))),
        const SizedBox(height: 8),
        Row(
          children: _genderOpts.map((opt) {
            final (gender, label, icon, color) = opt;
            final isSelected = _gender == gender;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _gender = gender),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isSelected ? color : border,
                        width: isSelected ? 1.5 : 1),
                  ),
                  child: Column(children: [
                    Icon(icon,
                        color: isSelected ? color : AppColors.grey400, size: 22),
                    const SizedBox(height: 4),
                    Text(label,
                        style: tt.labelSmall?.copyWith(
                            color: isSelected ? color : null,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400)),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Text('Has Luggage?',
              style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          Switch(
            value: _hasLuggage,
            onChanged: (v) => setState(() {
              _hasLuggage = v;
              if (!v) _luggageType = 'none';
              if (v && _luggageType == 'none') _luggageType = 'backpack';
            }),
          ),
        ]),
        if (_hasLuggage) ...[
          const SizedBox(height: 12),
          Row(children: [
            _luggageChip('backpack', 'Backpack', Icons.backpack_rounded, border),
            const SizedBox(width: 8),
            _luggageChip('suitcase', 'Suitcase', Icons.luggage_rounded, border),
          ]),
        ],
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
              child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'))),
          const SizedBox(width: 12),
          Expanded(
              child: ElevatedButton(
                  onPressed: () => Navigator.pop(
                      context,
                      _SeatDetails(
                          gender: _gender,
                          hasLuggage: _hasLuggage,
                          luggageType: _hasLuggage ? _luggageType : 'none')),
                  child: const Text('Confirm'))),
        ]),
      ]),
    );
  }

  Widget _luggageChip(String type, String label, IconData icon, Color border) {
    final tt = Theme.of(context).textTheme;
    final isSelected = _luggageType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _luggageType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isSelected ? AppColors.primary : border,
                width: isSelected ? 1.5 : 1),
          ),
          child: Column(children: [
            Icon(icon,
                color: isSelected ? AppColors.primary : AppColors.grey400, size: 20),
            const SizedBox(height: 4),
            Text(label,
                style: tt.labelSmall?.copyWith(
                    color: isSelected ? AppColors.primary : null,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w400)),
          ]),
        ),
      ),
    );
  }
}
"""

w("pages/seat_selection_page.dart", SEAT_SELECTION)
print("seat_selection_page.dart written!")
