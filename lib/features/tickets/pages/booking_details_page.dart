import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../bus_search/domain/repositories/booking_repository.dart';
import '../../bus_search/domain/repositories/trip_repository.dart';
import '../../bus_search/models/booking_data.dart';
import '../../bus_search/models/booking_response.dart';
import '../../bus_search/models/bus_model.dart';
import '../../bus_search/models/client_booking.dart';
import '../../bus_search/models/trip_response.dart';

class BookingDetailsPage extends StatefulWidget {
  final String bookingId;

  const BookingDetailsPage({super.key, required this.bookingId});

  @override
  State<BookingDetailsPage> createState() => _BookingDetailsPageState();
}

class _BookingDetailsPageState extends State<BookingDetailsPage> {
  ClientBooking? _booking;
  TripResponse? _trip;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final bookingRepo = RepositoryProvider.of<BookingRepository>(context);
      final tripRepo = RepositoryProvider.of<TripRepository>(context);

      final booking = await bookingRepo.getBookingDetails(widget.bookingId);
      if (!mounted) return;

      // Fetch trip details in parallel once we have the trip ID
      TripResponse? trip;
      try {
        trip = await tripRepo.getTrip(booking.tripId);
      } catch (_) {
        // Trip fetch failure is non-fatal — show booking without route info
      }

      if (mounted) {
        setState(() {
          _booking = booking;
          _trip = trip;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _canTrack() {
    final trip = _trip;
    if (trip == null) return false;
    if (_booking?.status != 'confirmed' && _booking?.status != 'boarded') return false;
    return trip.status != 'completed' && trip.status != 'cancelled';
  }

  void _navigateToPayment() {
    final booking = _booking;
    if (booking == null) return;
    final trip = _trip;

    final seats = booking.seats.map((s) {
      final gender = s.gender == 'female'
          ? SeatGender.female
          : s.gender == 'other'
              ? SeatGender.other
              : SeatGender.male;
      return SelectedSeat(
        seatId: s.seatId,
        seatNumber: int.tryParse(s.seatNumber) ?? 0,
        gender: gender,
        hasLuggage: s.hasLuggage,
        luggageType: s.luggageType ?? 'none',
      );
    }).toList();

    final bookingResponse = BookingResponse(
      id: booking.id,
      clientId: '',
      tripId: booking.tripId,
      status: booking.status,
      totalFare: booking.totalFare,
      holdDurationMinutes: booking.holdDurationMinutes,
      expiresAt: booking.expiresAt,
      createdAt: booking.createdAt,
    );

    String depTime = '';
    if (trip != null) {
      final h = trip.departureTime.hour.toString().padLeft(2, '0');
      final m = trip.departureTime.minute.toString().padLeft(2, '0');
      depTime = '$h:$m';
    }
    String arrTime = '';
    if (trip?.arrivalTime != null) {
      final h = trip!.arrivalTime!.hour.toString().padLeft(2, '0');
      final m = trip.arrivalTime!.minute.toString().padLeft(2, '0');
      arrTime = '$h:$m';
    }

    final bus = BusModel(
      id: booking.tripId,
      name: trip?.busModel ?? 'Booking #${booking.shortRef}',
      busNumber: trip?.busPlate ?? '',
      rating: 0,
      departureTime: depTime,
      arrivalTime: arrTime,
      duration: '',
      distanceKm: 0,
      pricePerSeat: booking.seats.isEmpty
          ? booking.totalFare
          : booking.totalFare / booking.seats.length,
      totalSeats: booking.seats.length,
      amenities: [],
      tags: [],
      prePopulatedSeats: [],
      imageUrl: trip?.busImage,
    );

    final data = BookingData(
      bus: bus,
      fromCity: trip?.origin ?? '',
      toCity: trip?.destination ?? '',
      date: trip?.departureTime ?? booking.createdAt,
      selectedSeats: seats,
      bookingResponse: bookingResponse,
    );

    context.push(AppRoutes.payment, extra: data);
  }

  void _share() {
    final b = _booking;
    if (b == null) return;

    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    String fmtDt(DateTime d) =>
        '${d.day} ${months[d.month - 1]} ${d.year}  '
        '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';

    final buf = StringBuffer();
    buf.writeln('🎫 Moovit Bus Booking');
    buf.writeln('─' * 30);
    buf.writeln('Ref: ${b.shortRef}');
    buf.writeln('Status: ${_statusLabel(b.status)}');
    buf.writeln();

    if (_trip != null) {
      final t = _trip!;
      final dep = t.departureTime;
      buf.writeln('🚌 Route');
      buf.writeln('  ${t.origin}  →  ${t.destination}');
      buf.writeln('  Departure: ${fmtDt(dep)}');
      if (t.arrivalTime != null) {
        buf.writeln('  Arrival:   ${fmtDt(t.arrivalTime!)}');
      }
      buf.writeln('  Bus: ${t.busModel}  (${t.busPlate})');
      buf.writeln();
    }

    buf.writeln('👥 Passengers');
    for (final s in b.seats) {
      final seat = s.seatNumber.isNotEmpty ? 'Seat ${s.seatNumber}' : '';
      final name = s.passengerName.isNotEmpty ? s.passengerName : 'Passenger';
      buf.writeln('  • $name  $seat');
      if (s.contactNumber.isNotEmpty) buf.writeln('    📞 ${s.contactNumber}');
      buf.writeln('    ${_cap(s.gender)}'
          '${s.hasLuggage ? "  •  ${_cap(s.luggageType ?? "Luggage")}" : ""}');
    }

    buf.writeln();
    if (b.familyPackage && b.discountAmount > 0) {
      buf.writeln('🏷️ Family Discount (10%): -GH₵ ${b.discountAmount.toStringAsFixed(2)}');
    }
    buf.writeln('💰 Total Fare: GH₵ ${b.totalFare.toStringAsFixed(2)}');
    buf.writeln('📅 Booked: ${fmtDt(b.createdAt)}');
    buf.writeln();
    buf.writeln('─' * 30);
    buf.writeln('Shared via Moovit Bus Ticketing');

    Share.share(buf.toString());
  }

  String _statusLabel(String s) => switch (s) {
        'confirmed' => 'Confirmed ✅',
        'pending' => 'Pending Payment ⏳',
        'cancelled' => 'Cancelled ❌',
        'boarded' => 'Completed 🎉',
        _ => s,
      };

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

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
        title: Text(
          'Booking Details',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_booking != null)
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Share booking',
              onPressed: _share,
            ),
        ],
      ),
      body: _isLoading
          ? _SkeletonDetails(isDark: isDark)
          : _error != null
              ? _ErrorBody(message: _error!, onRetry: _load, tt: tt, cs: cs)
              : _DetailsBody(
                  booking: _booking!,
                  trip: _trip,
                  isDark: isDark,
                  tt: tt,
                  cs: cs,
                  onShare: _share,
                  onPayNow: _booking!.status == 'pending' &&
                          _booking!.expiresAt.isAfter(DateTime.now().toUtc())
                      ? _navigateToPayment
                      : null,
                  onTrackBus: _canTrack()
                      ? () => context.push(
                            '/bus-tracking/${_booking!.tripId}',
                          )
                      : null,
                ),
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _SkeletonDetails extends StatelessWidget {
  const _SkeletonDetails({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.grey800 : AppColors.grey200,
      highlightColor: isDark ? AppColors.grey700 : AppColors.grey100,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _box(double.infinity, 100),
          const SizedBox(height: 12),
          _box(double.infinity, 130),
          const SizedBox(height: 12),
          _box(double.infinity, 200),
          const SizedBox(height: 12),
          _box(double.infinity, 160),
          const SizedBox(height: 12),
          _box(double.infinity, 120),
        ]),
      ),
    );
  }

  Widget _box(double w, double h) => Container(
        width: w, height: h,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      );
}

// ── Error ─────────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.message, required this.onRetry,
    required this.tt, required this.cs,
  });
  final String message;
  final VoidCallback onRetry;
  final TextTheme tt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha:0.1), shape: BoxShape.circle),
            child: const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 40),
          ),
          const SizedBox(height: 16),
          Text('Could not load details',
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
        ]),
      ),
    );
  }
}

// ── Main body ─────────────────────────────────────────────────────────────────

class _DetailsBody extends StatelessWidget {
  const _DetailsBody({
    required this.booking, required this.trip,
    required this.isDark, required this.tt,
    required this.cs, required this.onShare,
    this.onPayNow,
    this.onTrackBus,
  });

  final ClientBooking booking;
  final TripResponse? trip;
  final bool isDark;
  final TextTheme tt;
  final ColorScheme cs;
  final VoidCallback onShare;
  final VoidCallback? onPayNow;
  final VoidCallback? onTrackBus;

  bool get _isExpired =>
      booking.status == 'pending' &&
      booking.expiresAt.isBefore(DateTime.now().toUtc());

  Color get _statusColor {
    if (_isExpired) return AppColors.grey400;
    return switch (booking.status) {
      'confirmed' => AppColors.success,
      'pending'   => const Color(0xFFF59E0B),
      'cancelled' => AppColors.error,
      'boarded'   => AppColors.primary,
      _           => AppColors.grey400,
    };
  }

  String get _statusLabel {
    if (_isExpired) return 'Hold Expired';
    return switch (booking.status) {
      'confirmed' => 'Confirmed',
      'pending'   => 'Pending Payment',
      'cancelled' => 'Cancelled',
      'boarded'   => 'Boarded',
      _           => booking.status,
    };
  }

  IconData get _statusIcon {
    if (_isExpired) return Icons.timer_off_rounded;
    return switch (booking.status) {
      'confirmed' => Icons.check_circle_rounded,
      'pending'   => Icons.hourglass_top_rounded,
      'cancelled' => Icons.cancel_rounded,
      'boarded'   => Icons.directions_bus_rounded,
      _           => Icons.info_rounded,
    };
  }

  String _fmtDt(DateTime d) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year}  $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final border = isDark ? AppColors.darkOutline : AppColors.lightOutline;
    final subtle = isDark
        ? AppColors.darkOnSurfaceVariant
        : AppColors.lightOnSurfaceVariant;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [

        // ── Status header ──────────────────────────────────────────────
        _Card(isDark: isDark, child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _statusColor.withValues(alpha:0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_statusIcon, color: _statusColor, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_statusLabel,
                  style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700, color: _statusColor)),
              const SizedBox(height: 2),
              Text('Ref: ${booking.shortRef}',
                  style: tt.bodySmall?.copyWith(color: subtle)),
            ],
          )),
          _Badge(
            label: booking.familyPackage ? 'Family' : 'Standard',
            color: cs.primary, tt: tt,
          ),
        ])),
        const SizedBox(height: 12),

        // ── Trip info (if available) ───────────────────────────────────
        if (trip != null) ...[
          _Card(isDark: isDark, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Trip Details',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip!.origin,
                        style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700)),
                    Text('Departure', style: tt.bodySmall?.copyWith(color: subtle)),
                  ],
                )),
                Column(children: [
                  Icon(Icons.directions_bus_rounded, color: cs.primary, size: 20),
                  const SizedBox(height: 4),
                  Container(width: 60, height: 1, color: border),
                ]),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(trip!.destination,
                        style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700)),
                    Text('Arrival', style: tt.bodySmall?.copyWith(color: subtle)),
                  ],
                )),
              ]),
              const SizedBox(height: 12),
              Divider(height: 1, color: border),
              const SizedBox(height: 12),
              _InfoRow(label: 'Departure', value: _fmtDt(trip!.departureTime),
                  tt: tt, subtle: subtle),
              if (trip!.arrivalTime != null) ...[
                const SizedBox(height: 6),
                _InfoRow(label: 'Arrival', value: _fmtDt(trip!.arrivalTime!),
                    tt: tt, subtle: subtle),
              ],
              const SizedBox(height: 6),
              _InfoRow(label: 'Bus', value: trip!.busModel, tt: tt, subtle: subtle),
              const SizedBox(height: 6),
              _InfoRow(label: 'Plate', value: trip!.busPlate, tt: tt, subtle: subtle),
            ],
          )),
          const SizedBox(height: 12),
        ],

        // ── QR Code (confirmed / boarded) ─────────────────────────────
        if ((booking.status == 'confirmed' || booking.status == 'boarded') &&
            booking.qrImageBase64 != null &&
            booking.qrImageBase64!.isNotEmpty) ...[
          _QrCard(base64Image: booking.qrImageBase64!, isDark: isDark, tt: tt),
          const SizedBox(height: 12),
        ],

        // ── Passengers ─────────────────────────────────────────────────
        _Card(isDark: isDark, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Passengers (${booking.seats.length})',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            ...booking.seats.asMap().entries.map((e) => _SeatRow(
              index: e.key + 1,
              seat: e.value,
              isDark: isDark, tt: tt, subtle: subtle,
              cs: cs, border: border,
              isLast: e.key == booking.seats.length - 1,
            )),
          ],
        )),
        const SizedBox(height: 12),

        // ── Fare ───────────────────────────────────────────────────────
        _Card(isDark: isDark, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fare Summary',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            _InfoRow(
              label: 'Seats',
              value: '${booking.seats.length} × GH₵ '
                  '${booking.familyPackage && booking.discountAmount > 0 && booking.seats.isNotEmpty
                      ? ((booking.totalFare + booking.discountAmount) / booking.seats.length).toStringAsFixed(2)
                      : (booking.totalFare / (booking.seats.isEmpty ? 1 : booking.seats.length)).toStringAsFixed(2)}',
              tt: tt, subtle: subtle,
            ),
            if (booking.familyPackage && booking.discountAmount > 0) ...[
              const SizedBox(height: 8),
              _InfoRow(
                label: 'Family Discount (10%)',
                value: '- GH₵ ${booking.discountAmount.toStringAsFixed(2)}',
                tt: tt, subtle: subtle,
                valueColor: const Color(0xFF16A34A),
              ),
            ],
            const SizedBox(height: 8),
            Divider(height: 1, color: border),
            const SizedBox(height: 8),
            _InfoRow(
              label: 'Total',
              value: 'GH₵ ${booking.totalFare.toStringAsFixed(2)}',
              tt: tt, subtle: subtle,
              bold: true, valueColor: cs.primary,
            ),
          ],
        )),
        const SizedBox(height: 12),

        // ── Boarding / Scan info ────────────────────────────────────────
        if (booking.boardedAt != null) ...[
          _Card(isDark: isDark, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha:0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded,
                      color: AppColors.success, size: 20),
                ),
                const SizedBox(width: 12),
                Text('Ticket Scanned',
                    style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.success)),
              ]),
              const SizedBox(height: 14),
              _InfoRow(label: 'Scanned At', value: _fmtDt(booking.boardedAt!),
                  tt: tt, subtle: subtle, valueColor: AppColors.success),
              if (booking.scannedByDriverName != null &&
                  booking.scannedByDriverName!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _InfoRow(label: 'Scanned By', value: booking.scannedByDriverName!,
                    tt: tt, subtle: subtle, bold: true),
              ],
            ],
          )),
          const SizedBox(height: 12),
        ],

        // ── Booking info ───────────────────────────────────────────────
        _Card(isDark: isDark, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Booking Info',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            _InfoRow(label: 'Booked On', value: _fmtDt(booking.createdAt),
                tt: tt, subtle: subtle),
            if (booking.status == 'pending') ...[
              const SizedBox(height: 8),
              _InfoRow(
                label: _isExpired ? 'Hold Expired' : 'Hold Expires',
                value: _fmtDt(booking.expiresAt),
                tt: tt, subtle: subtle,
                valueColor: _isExpired ? AppColors.grey400 : AppColors.error,
              ),
              const SizedBox(height: 8),
              _InfoRow(label: 'Hold Duration',
                  value: '${booking.holdDurationMinutes} min',
                  tt: tt, subtle: subtle),
            ],
          ],
        )),
        const SizedBox(height: 16),

        // ── Pay Now button (pending only) ──────────────────────────────
        if (onPayNow != null) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onPayNow,
              icon: const Icon(Icons.payment_rounded, size: 18),
              label: Text(
                  'Pay Now — GH₵ ${booking.totalFare.toStringAsFixed(2)}'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],

        // ── Track Bus button (confirmed / boarded, non-terminal trips) ─
        if (onTrackBus != null) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onTrackBus,
              icon: const Icon(Icons.location_on_rounded, size: 18),
              label: const Text('Track Bus'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],

        // ── Share button ───────────────────────────────────────────────
        OutlinedButton.icon(
          onPressed: onShare,
          icon: const Icon(Icons.share_rounded, size: 18),
          label: const Text('Share Booking Details'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),

        // ── Rate Trip button (scanned/boarded passengers only) ───────────
        if (booking.status == 'boarded' && trip != null)
          Builder(builder: (context) {
            final t = trip!;
            return Column(children: [
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push(
                    AppRoutes.submitRating,
                    extra: {
                      'tripId': booking.tripId,
                      'tripOrigin': t.origin,
                      'tripDestination': t.destination,
                      'driverName': null,
                      'departureTime': t.departureTime,
                    },
                  ),
                  icon: const Icon(Icons.star_rounded, size: 18),
                  label: const Text('Rate Trip & Driver'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ]);
          }),

        // ── Report Issue button (confirmed or boarded) ─────────────────────────
        if ((booking.status == 'confirmed' || booking.status == 'boarded') &&
            trip != null)
          Builder(builder: (context) {
            final t = trip!;
            return Column(children: [
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push(
                    AppRoutes.submitComplaint,
                    extra: {
                      'tripId': booking.tripId,
                      'tripOrigin': t.origin,
                      'tripDestination': t.destination,
                      'departureTime': t.departureTime,
                    },
                  ),
                  icon: const Icon(Icons.report_problem_rounded, size: 18),
                  label: const Text('Report Issue'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ]);
          }),
      ],
    );
  }
}

// ── QR Card ───────────────────────────────────────────────────────────────────

class _QrCard extends StatelessWidget {
  const _QrCard({required this.base64Image, required this.isDark, required this.tt});
  final String base64Image;
  final bool isDark;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final imageBytes = base64Decode(
      base64Image.contains(',') ? base64Image.split(',').last : base64Image,
    );

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha:0.4), width: 1.5),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.qr_code_2_rounded, color: AppColors.success, size: 20),
          const SizedBox(width: 8),
          Text('Show this QR to the driver',
              style: tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600, color: AppColors.success)),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Image.memory(imageBytes, width: 200, height: 200,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox(
                width: 200, height: 200,
                child: Center(child: Icon(Icons.qr_code_rounded,
                    size: 80, color: AppColors.grey400)),
              )),
        ),
      ]),
    );
  }
}

// ── Seat row ──────────────────────────────────────────────────────────────────

class _SeatRow extends StatelessWidget {
  const _SeatRow({
    required this.index, required this.seat,
    required this.isDark, required this.tt,
    required this.subtle, required this.cs,
    required this.border, required this.isLast,
  });

  final int index;
  final BookingSeatDetail seat;
  final bool isDark;
  final TextTheme tt;
  final Color subtle;
  final ColorScheme cs;
  final Color border;
  final bool isLast;

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Seat number badge
        Container(
          width: 44,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            Text('Seat', style: TextStyle(fontSize: 9, color: cs.primary)),
            Text(
              seat.seatNumber.isNotEmpty ? seat.seatNumber : '$index',
              style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800, color: cs.primary),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              seat.passengerName.isNotEmpty ? seat.passengerName : 'Passenger $index',
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            if (seat.contactNumber.isNotEmpty)
              Row(children: [
                Icon(Icons.phone_rounded, size: 12, color: subtle),
                const SizedBox(width: 4),
                Text(seat.contactNumber,
                    style: tt.bodySmall?.copyWith(color: subtle)),
              ]),
            const SizedBox(height: 2),
            Row(children: [
              Icon(
                seat.gender == 'female'
                    ? Icons.female_rounded
                    : Icons.male_rounded,
                size: 14, color: subtle,
              ),
              const SizedBox(width: 3),
              Text(_cap(seat.gender),
                  style: tt.bodySmall?.copyWith(color: subtle)),
              if (seat.hasLuggage) ...[
                const SizedBox(width: 10),
                Icon(Icons.luggage_rounded, size: 14, color: cs.primary),
                const SizedBox(width: 3),
                Text(_cap(seat.luggageType ?? 'luggage'),
                    style: tt.bodySmall?.copyWith(color: subtle)),
              ],
            ]),
          ],
        )),
      ]),
      if (!isLast) ...[
        const SizedBox(height: 10),
        Divider(height: 1, color: border),
        const SizedBox(height: 10),
      ],
    ]);
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.isDark, required this.child});
  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.darkOutline : AppColors.lightOutline),
        boxShadow: isDark
            ? []
            : [BoxShadow(
                color: Colors.black.withValues(alpha:0.04),
                blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label, required this.value,
    required this.tt, required this.subtle,
    this.bold = false, this.valueColor,
  });

  final String label;
  final String value;
  final TextTheme tt;
  final Color subtle;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: tt.bodySmall?.copyWith(color: subtle)),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.end,
              style: (bold ? tt.bodyMedium : tt.bodySmall)?.copyWith(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                  color: valueColor)),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, required this.tt});
  final String label;
  final Color color;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: tt.labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w700)),
    );
  }
}
