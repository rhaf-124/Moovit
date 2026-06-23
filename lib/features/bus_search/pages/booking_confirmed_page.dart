import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../models/booking_data.dart';
import '../models/bus_model.dart';

class BookingConfirmedPage extends StatelessWidget {
  final BookingData data;
  const BookingConfirmedPage({super.key, required this.data});

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  String _genderLabel(SeatGender g) => switch (g) {
        SeatGender.male => 'Male',
        SeatGender.female => 'Female',
        SeatGender.other => 'Other',
      };

  Color _genderColor(SeatGender g) => switch (g) {
        SeatGender.male => const Color(0xFF4B7BF5),
        SeatGender.female => const Color(0xFFEC4899),
        SeatGender.other => const Color(0xFF8B5CF6),
      };

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final d = data;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),

                      // ── Success icon ──────────────────────────────────
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // confetti dots
                          ..._confettiDots(),
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.success.withValues(alpha:0.3),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 52,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Title ─────────────────────────────────────────
                      Text(
                        'Booking Confirmed!',
                        style: tt.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your booking has been confirmed successfully.',
                        style: tt.bodyMedium?.copyWith(
                          color: isDark
                              ? AppColors.darkOnSurfaceVariant
                              : AppColors.lightOnSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Booking ID: ${d.bookingId}',
                        style: tt.bodySmall?.copyWith(
                          color: AppColors.grey400,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (d.confirmedBooking?.qrImageBase64 != null &&
                          d.confirmedBooking!.qrImageBase64!.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkOutline
                                  : AppColors.lightOutline,
                            ),
                            boxShadow: isDark
                                ? []
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha:0.04),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(d.confirmedBooking!.qrImageBase64!),
                              width: 140,
                              height: 140,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.qr_code_2_rounded,
                                  size: 140,
                                  color: AppColors.grey400,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Show this QR code at boarding',
                          style: tt.labelMedium?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ] else
                        const SizedBox(height: 24),

                      // ── Bus card ──────────────────────────────────────
                      _buildBusCard(d, tt, cs, isDark),
                      const SizedBox(height: 20),

                      // ── Passenger details ─────────────────────────────
                      _buildPassengerDetails(d, tt, cs, isDark),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // ── Home button ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go(AppRoutes.home),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Home'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bus card ────────────────────────────────────────────────────────────────

  Widget _buildBusCard(
    BookingData d,
    TextTheme tt,
    ColorScheme cs,
    bool isDark,
  ) {
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
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.directions_bus_rounded,
                        color: cs.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.bus.name,
                          style: tt.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(d.bus.busNumber,
                          style: tt.bodySmall
                              ?.copyWith(color: AppColors.grey400)),
                    ],
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha:0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'CONFIRMED',
                  style: tt.labelSmall?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Times row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.bus.departureTime,
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text(d.fromCity,
                      style: tt.bodySmall?.copyWith(color: subtle)),
                  Text(_fmtDate(d.date),
                      style: tt.bodySmall?.copyWith(color: AppColors.grey400)),
                ],
              ),
              Column(
                children: [
                  const Icon(Icons.arrow_forward_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    d.bus.duration,
                    style: tt.bodySmall?.copyWith(color: AppColors.grey400),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(d.bus.arrivalTime,
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text(d.toCity,
                      style: tt.bodySmall?.copyWith(color: subtle)),
                  Text(
                    'Next Day',
                    style: tt.bodySmall?.copyWith(color: AppColors.grey400),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(
              height: 1,
              color: isDark ? AppColors.darkOutline : AppColors.lightOutline),
          const SizedBox(height: 14),

          // Seats row
          Row(
            children: [
              Icon(Icons.event_seat_rounded, color: cs.primary, size: 18),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Selected Seats',
                      style: tt.bodySmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      )),
                  Text(
                    d.selectedSeats
                        .map((s) => s.seatNumber.toString())
                        .join(', '),
                    style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '${d.selectedSeats.length} Seat${d.selectedSeats.length > 1 ? 's' : ''}',
                style: tt.bodySmall?.copyWith(
                  color: AppColors.grey500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Passenger details ───────────────────────────────────────────────────────

  Widget _buildPassengerDetails(
    BookingData d,
    TextTheme tt,
    ColorScheme cs,
    bool isDark,
  ) {
    final card = isDark ? AppColors.darkSurface : AppColors.white;
    final border = isDark ? AppColors.darkOutline : AppColors.lightOutline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Passenger Details',
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Column(
            children: d.selectedSeats.indexed.map((entry) {
              final i = entry.$1;
              final seat = entry.$2;
              final isLast = i == d.selectedSeats.length - 1;
              final color = _genderColor(seat.gender);

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha:0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '${seat.seatNumber}',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Passenger ${i + 1}',
                              style: tt.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha:0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _genderLabel(seat.gender).toUpperCase(),
                                style: tt.labelSmall?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          'Seat ${seat.seatNumber}',
                          style: tt.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Divider(height: 1, indent: 16, endIndent: 16, color: border),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Confetti dots ───────────────────────────────────────────────────────────

  List<Widget> _confettiDots() {
    const dots = [
      (dx: -80.0, dy: -40.0, color: Color(0xFF4B7BF5), size: 8.0),
      (dx: 80.0, dy: -40.0, color: Color(0xFFEC4899), size: 6.0),
      (dx: -70.0, dy: 40.0, color: Color(0xFFF59E0B), size: 7.0),
      (dx: 70.0, dy: 40.0, color: Color(0xFF8B5CF6), size: 5.0),
      (dx: -50.0, dy: -70.0, color: Color(0xFF22C55E), size: 5.0),
      (dx: 50.0, dy: -70.0, color: Color(0xFFF97316), size: 6.0),
      (dx: 0.0, dy: -90.0, color: Color(0xFF4B7BF5), size: 5.0),
      (dx: -90.0, dy: 10.0, color: Color(0xFFEC4899), size: 4.0),
      (dx: 90.0, dy: 10.0, color: Color(0xFF22C55E), size: 4.0),
    ];

    return dots
        .map(
          (d) => Transform.translate(
            offset: Offset(d.dx, d.dy),
            child: Container(
              width: d.size,
              height: d.size,
              decoration: BoxDecoration(
                color: d.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        )
        .toList();
  }
}
