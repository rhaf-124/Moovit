import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../bus_search/domain/repositories/booking_repository.dart';
import '../../bus_search/models/booking_data.dart';
import '../../bus_search/models/booking_response.dart';
import '../../bus_search/models/bus_model.dart';
import '../../bus_search/models/client_booking.dart';

class TicketsPage extends StatefulWidget {
  const TicketsPage({super.key});

  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ClientBooking> _bookings = [];
  bool _isLoading = true;
  String? _error;
  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    // Re-evaluate hold expiry every second so "Pay Now"/"Expired" stay
    // accurate even if the user just leaves this list open.
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = RepositoryProvider.of<BookingRepository>(context);
      final bookings = await repo.listBookings();
      if (mounted) setState(() => _bookings = bookings);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Tickets',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: _isLoading
          ? _SkeletonList(isDark: isDark)
          : _error != null
              ? _ErrorState(
                  message: _error!,
                  onRetry: _load,
                  tt: tt,
                  cs: cs,
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _TicketList(
                      bookings: _bookings.where((b) => b.isUpcoming).toList(),
                      isDark: isDark,
                      tt: tt,
                      cs: cs,
                      label: 'upcoming',
                      onRefresh: _load,
                    ),
                    _TicketList(
                      bookings: _bookings.where((b) => b.isCompleted).toList(),
                      isDark: isDark,
                      tt: tt,
                      cs: cs,
                      label: 'completed',
                      onRefresh: _load,
                    ),
                    _TicketList(
                      bookings: _bookings.where((b) => b.isCancelled).toList(),
                      isDark: isDark,
                      tt: tt,
                      cs: cs,
                      label: 'cancelled',
                      onRefresh: _load,
                    ),
                  ],
                ),
    );
  }
}

// ── Skeleton loading ──────────────────────────────────────────────────────────

class _SkeletonList extends StatelessWidget {
  const _SkeletonList({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final base = isDark ? AppColors.grey800 : AppColors.grey200;
    final highlight = isDark ? AppColors.grey700 : AppColors.grey100;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => _SkeletonCard(),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkSurface : AppColors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _box(width: 120, height: 14),
              _box(width: 72, height: 22, radius: 20),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _box(width: 80, height: 20),
              _box(width: 32, height: 32, radius: 16),
              _box(width: 80, height: 20),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _box(width: 70, height: 14),
              _box(width: 70, height: 14),
              _box(width: 70, height: 14),
            ],
          ),
        ],
      ),
    );
  }

  Widget _box({required double width, required double height, double radius = 6}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.tt,
    required this.cs,
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
            Text('Could not load tickets',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              style: tt.bodySmall?.copyWith(color: AppColors.grey500),
              textAlign: TextAlign.center,
            ),
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

// ── Ticket list ───────────────────────────────────────────────────────────────

class _TicketList extends StatelessWidget {
  const _TicketList({
    required this.bookings,
    required this.isDark,
    required this.tt,
    required this.cs,
    required this.label,
    required this.onRefresh,
  });

  final List<ClientBooking> bookings;
  final bool isDark;
  final TextTheme tt;
  final ColorScheme cs;
  final String label;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.confirmation_number_outlined,
                      size: 72,
                      color: isDark ? AppColors.grey700 : AppColors.grey300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No $label tickets',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.grey500 : AppColors.grey400,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your $label bookings will appear here.',
                      style: tt.bodySmall?.copyWith(
                        color: isDark ? AppColors.grey600 : AppColors.grey400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: bookings.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final booking = bookings[i];
          return GestureDetector(
            onTap: () => context.push('/booking-details/${booking.id}'),
            child: _TicketCard(
              booking: booking,
              isDark: isDark,
              tt: tt,
              cs: cs,
              onPayNow: booking.status == 'pending' &&
                      booking.expiresAt.isAfter(DateTime.now().toUtc())
                  ? () => _navigateToPayment(context, booking)
                  : null,
            ),
          );
        },
      ),
    );
  }

  void _navigateToPayment(BuildContext context, ClientBooking booking) {
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

    final bus = BusModel(
      id: booking.tripId,
      name: 'Booking #${booking.shortRef}',
      busNumber: '',
      rating: 0,
      departureTime: '',
      arrivalTime: '',
      duration: '',
      distanceKm: 0,
      pricePerSeat: booking.seats.isEmpty
          ? booking.totalFare
          : booking.totalFare / booking.seats.length,
      totalSeats: booking.seats.length,
      amenities: [],
      tags: [],
      prePopulatedSeats: [],
    );

    final data = BookingData(
      bus: bus,
      fromCity: '',
      toCity: '',
      date: booking.createdAt,
      selectedSeats: seats,
      bookingResponse: bookingResponse,
    );

    context.push(AppRoutes.payment, extra: data);
  }
}

// ── Ticket card ───────────────────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  const _TicketCard({
    required this.booking,
    required this.isDark,
    required this.tt,
    required this.cs,
    this.onPayNow,
  });

  final ClientBooking booking;
  final bool isDark;
  final TextTheme tt;
  final ColorScheme cs;
  final VoidCallback? onPayNow;

  bool get _isExpired =>
      booking.status == 'pending' &&
      booking.expiresAt.isBefore(DateTime.now().toUtc());

  Color get _statusColor {
    if (_isExpired) return AppColors.grey400;
    return switch (booking.status) {
      'confirmed' => AppColors.success,
      'pending' => const Color(0xFFF59E0B),
      'cancelled' => AppColors.error,
      'boarded' => AppColors.primary,
      _ => AppColors.grey400,
    };
  }

  String get _statusLabel {
    if (_isExpired) return 'Expired';
    return switch (booking.status) {
      'confirmed' => 'Confirmed',
      'pending' => 'Pending',
      'cancelled' => 'Cancelled',
      'boarded' => 'Boarded',
      _ => booking.status,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = isDark ? AppColors.darkSurface : AppColors.white;
    final borderColor = isDark ? AppColors.darkOutline : AppColors.lightOutline;
    final subtle = isDark
        ? AppColors.darkOnSurfaceVariant
        : AppColors.lightOnSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        children: [
          // ── Top section ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Booking #${booking.shortRef}',
                      style: tt.bodySmall?.copyWith(color: subtle),
                    ),
                    _StatusBadge(
                      label: _statusLabel,
                      color: _statusColor,
                      tt: tt,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Seat count display
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.confirmation_number_rounded,
                          color: cs.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${booking.seats.length} ${booking.seats.length == 1 ? 'Seat' : 'Seats'} booked',
                            style: tt.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            booking.familyPackage
                                ? 'Family Package'
                                : 'Standard Booking',
                            style:
                                tt.bodySmall?.copyWith(color: subtle),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'GH₵ ${booking.totalFare.toStringAsFixed(2)}',
                      style: tt.titleSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Tear divider ─────────────────────────────────────────────────
          Row(
            children: [
              _Notch(isDark: isDark),
              Expanded(
                child: LayoutBuilder(
                  builder: (_, c) => Flex(
                    direction: Axis.horizontal,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      (c.maxWidth / 10).floor(),
                      (_) => Container(
                        width: 5,
                        height: 1,
                        color: borderColor,
                      ),
                    ),
                  ),
                ),
              ),
              _Notch(isDark: isDark, right: true),
            ],
          ),

          // ── Bottom section ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _InfoCol(
                  label: 'Booked On',
                  value: _fmtDate(booking.createdAt),
                  tt: tt,
                  subtle: subtle,
                ),
                if (booking.status == 'pending' && !_isExpired)
                  _InfoCol(
                    label: 'Expires',
                    value: _fmtDate(booking.expiresAt),
                    tt: tt,
                    subtle: subtle,
                    valueColor: AppColors.error,
                  )
                else if (_isExpired)
                  _InfoCol(
                    label: 'Expired',
                    value: _fmtDate(booking.expiresAt),
                    tt: tt,
                    subtle: subtle,
                    valueColor: AppColors.grey400,
                  )
                else if (booking.boardedAt != null)
                  _InfoCol(
                    label: 'Boarded',
                    value: _fmtDate(booking.boardedAt!),
                    tt: tt,
                    subtle: subtle,
                  )
                else
                  _InfoCol(
                    label: 'Seats',
                    value: booking.seats.length.toString(),
                    tt: tt,
                    subtle: subtle,
                  ),
                _InfoCol(
                  label: 'Status',
                  value: _statusLabel,
                  tt: tt,
                  subtle: subtle,
                  valueColor: _statusColor,
                ),
              ],
            ),
          ),

          // ── Pay Now strip (pending only) ─────────────────────────────────
          if (onPayNow != null)
            InkWell(
              onTap: onPayNow,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha:0.1),
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.payment_rounded,
                        size: 16, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 6),
                    Text(
                      'Pay Now to Confirm Seat',
                      style: tt.labelMedium?.copyWith(
                        color: const Color(0xFFF59E0B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 14, color: Color(0xFFF59E0B)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.tt,
  });

  final String label;
  final Color color;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: tt.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Notch extends StatelessWidget {
  const _Notch({required this.isDark, this.right = false});

  final bool isDark;
  final bool right;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      transform: Matrix4.translationValues(right ? 8 : -8, 0, 0),
    );
  }
}

class _InfoCol extends StatelessWidget {
  const _InfoCol({
    required this.label,
    required this.value,
    required this.tt,
    required this.subtle,
    this.valueColor,
  });

  final String label;
  final String value;
  final TextTheme tt;
  final Color subtle;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: tt.bodySmall?.copyWith(color: subtle)),
        const SizedBox(height: 2),
        Text(
          value,
          style: tt.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
