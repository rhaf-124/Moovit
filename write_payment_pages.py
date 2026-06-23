#!/usr/bin/env python3
"""Writes payment_page, paystack_webview_page, payment_processing_page, booking_confirmed_page."""
import os

BASE = r"lib\features\bus_search\pages"

def w(filename, content):
    path = os.path.join(BASE, filename)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Written: {path}")


# ── PaymentPage ───────────────────────────────────────────────────────────────

PAYMENT_PAGE = r"""import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/repositories/booking_repository.dart';
import '../models/booking_data.dart';
import '../models/bus_model.dart';

class PaymentPage extends StatefulWidget {
  final BookingData data;
  const PaymentPage({super.key, required this.data});
  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String _method = 'paystack';
  bool _isPaying = false;
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  static const _methods = [
    ('paystack', 'Paystack', 'Pay securely with your card via Paystack',
        Icons.credit_card_rounded, Color(0xFF00C3F7)),
    ('mock', 'Mock Payment', 'Instant confirmation — for testing only',
        Icons.science_rounded, Color(0xFF8B5CF6)),
  ];

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    final expiresAt = widget.data.bookingResponse?.expiresAt;
    if (expiresAt == null) return;
    _updateRemaining(expiresAt);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _updateRemaining(expiresAt);
      if (_remaining == Duration.zero) {
        _countdownTimer?.cancel();
        _showExpiredDialog();
      }
    });
  }

  void _updateRemaining(DateTime expiresAt) {
    final diff = expiresAt.difference(DateTime.now().toUtc());
    setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
  }

  void _showExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Hold Expired'),
        content: const Text('Your seat reservation expired. Please search again.'),
        actions: [
          TextButton(
            onPressed: () { Navigator.of(context).pop(); context.go(AppRoutes.home); },
            child: const Text('Back to Search'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _formatCountdown(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  String _genderLabel(SeatGender g) => switch (g) {
        SeatGender.male => 'Male',
        SeatGender.female => 'Female',
        SeatGender.other => 'Other',
      };

  Future<void> _onPay() async {
    setState(() => _isPaying = true);
    try {
      final repo = RepositoryProvider.of<BookingRepository>(context);
      final paymentResp = await repo.initiatePayment(
          bookingId: widget.data.bookingId, method: _method);
      if (!mounted) return;

      final updatedData = widget.data.copyWith(paymentResponse: paymentResp);

      if (_method == 'mock') {
        // Mock: immediately confirmed
        context.pushReplacement(AppRoutes.paymentProcessing, extra: updatedData);
      } else {
        // Paystack: open WebView
        context.push(AppRoutes.paystackWebview, extra: updatedData);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Payment init failed: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final d = widget.data;
    final hasExpiry = d.bookingResponse != null;
    final isWarning = hasExpiry && _remaining.inMinutes < 5;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.pop()),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Payment',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          Text('Complete your booking',
              style: tt.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.darkOnSurfaceVariant
                      : AppColors.lightOnSurfaceVariant)),
        ]),
        actions: [
          if (hasExpiry)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isWarning
                    ? AppColors.error.withOpacity(0.15)
                    : AppColors.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isWarning ? AppColors.error : AppColors.success),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.timer_rounded,
                    size: 14,
                    color: isWarning ? AppColors.error : AppColors.success),
                const SizedBox(width: 4),
                Text(_formatCountdown(_remaining),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isWarning ? AppColors.error : AppColors.success)),
              ]),
            ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lock_rounded, color: AppColors.success, size: 12),
              const SizedBox(width: 4),
              Text('Secure',
                  style: tt.labelSmall?.copyWith(
                      color: AppColors.success, fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // ── Booking summary ──────────────────────────────────────────
        _sectionLabel('Booking Summary', tt),
        const SizedBox(height: 10),
        _buildBookingSummary(d, tt, cs, isDark),
        const SizedBox(height: 20),

        // ── Passengers ───────────────────────────────────────────────
        _sectionLabel('Passengers & Seats', tt),
        const SizedBox(height: 10),
        _buildPassengerList(d, tt, cs, isDark),
        const SizedBox(height: 20),

        // ── Payment method ───────────────────────────────────────────
        _sectionLabel('Payment Method', tt),
        const SizedBox(height: 10),
        _buildPaymentMethods(tt, cs, isDark),
        const SizedBox(height: 16),

        Row(children: [
          const Icon(Icons.lock_rounded, color: AppColors.success, size: 14),
          const SizedBox(width: 6),
          Expanded(
              child: Text('Your payment is secured and encrypted',
                  style: tt.bodySmall?.copyWith(color: AppColors.grey500))),
        ]),
        const SizedBox(height: 24),

        // ── Pay button ───────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isPaying ? null : _onPay,
            icon: _isPaying
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.payment_rounded, size: 18),
            label: Text(_isPaying
                ? 'Processing...'
                : 'Pay \$${d.total.toStringAsFixed(2)} via ${_method == "paystack" ? "Paystack" : "Mock"}'),
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
          ),
        ),
        const SizedBox(height: 12),
        Text('By proceeding, you agree to our Terms & Conditions',
            style: tt.bodySmall?.copyWith(color: AppColors.grey400),
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _sectionLabel(String text, TextTheme tt) =>
      Text(text, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700));

  Widget _buildBookingSummary(
      BookingData d, TextTheme tt, ColorScheme cs, bool isDark) {
    final card = isDark ? AppColors.darkSurface : AppColors.white;
    final border = isDark ? AppColors.darkOutline : AppColors.lightOutline;
    final subtle =
        isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(d.bus.name,
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          Text(d.bus.departureTime,
              style: tt.titleSmall
                  ?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${d.fromCity} → ${d.toCity}',
              style: tt.bodySmall?.copyWith(color: subtle)),
          Text(d.bus.busNumber,
              style: tt.bodySmall?.copyWith(color: AppColors.grey400)),
        ]),
        const SizedBox(height: 4),
        Align(
            alignment: Alignment.centerLeft,
            child: Text(_fmtDate(d.date),
                style: tt.bodySmall?.copyWith(color: subtle))),
        if (d.bookingResponse != null) ...[
          const Divider(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total Fare:',
                style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            Text('\$${d.total.toStringAsFixed(2)}',
                style: tt.titleSmall?.copyWith(
                    color: cs.primary, fontWeight: FontWeight.w700)),
          ]),
        ],
      ]),
    );
  }

  Widget _buildPassengerList(
      BookingData d, TextTheme tt, ColorScheme cs, bool isDark) {
    final card = isDark ? AppColors.darkSurface : AppColors.white;
    final border = isDark ? AppColors.darkOutline : AppColors.lightOutline;
    return Container(
      decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border)),
      child: Column(
          children: d.selectedSeats.indexed.map((entry) {
        final i = entry.$1;
        final seat = entry.$2;
        final isLast = i == d.selectedSeats.length - 1;
        final color = _genderColor(seat.gender);
        return Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Seat ${seat.seatNumber} — ${_genderLabel(seat.gender)}',
                        style: tt.bodyMedium),
                    if (seat.hasLuggage)
                      Text('Luggage: ${seat.luggageType}',
                          style: tt.bodySmall
                              ?.copyWith(color: AppColors.grey400)),
                  ])),
              Text('\$${d.bus.pricePerSeat.toStringAsFixed(2)}',
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ]),
          ),
          if (!isLast) Divider(height: 1, indent: 34, color: border),
        ]);
      }).toList()),
    );
  }

  Widget _buildPaymentMethods(TextTheme tt, ColorScheme cs, bool isDark) {
    final card = isDark ? AppColors.darkSurface : AppColors.white;
    final border = isDark ? AppColors.darkOutline : AppColors.lightOutline;
    return Column(
        children: _methods.map((m) {
      final (id, label, sub, icon, color) = m;
      final isSelected = _method == id;
      return GestureDetector(
        onTap: () => setState(() => _method = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.06) : card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isSelected ? color : border,
                width: isSelected ? 1.5 : 1),
          ),
          child: Row(children: [
            Radio<String>(
                value: id, groupValue: _method,
                onChanged: (v) => setState(() => _method = v!),
                activeColor: color),
            const SizedBox(width: 4),
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label,
                      style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? color : null)),
                  Text(sub,
                      style: tt.bodySmall?.copyWith(color: AppColors.grey400)),
                ])),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: color, size: 20),
          ]),
        ),
      );
    }).toList());
  }

  Color _genderColor(SeatGender g) => switch (g) {
        SeatGender.male => const Color(0xFF4B7BF5),
        SeatGender.female => const Color(0xFFEC4899),
        SeatGender.other => const Color(0xFF8B5CF6),
      };
}
"""

# ── PaystackWebviewPage ───────────────────────────────────────────────────────

PAYSTACK_WEBVIEW = r"""import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/repositories/booking_repository.dart';
import '../models/booking_data.dart';

class PaystackWebviewPage extends StatefulWidget {
  final BookingData data;
  const PaystackWebviewPage({super.key, required this.data});
  @override
  State<PaystackWebviewPage> createState() => _PaystackWebviewPageState();
}

class _PaystackWebviewPageState extends State<PaystackWebviewPage> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    final checkoutUrl = widget.data.paymentResponse?.checkoutUrl ?? '';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _isLoading = true),
        onPageFinished: (_) => setState(() => _isLoading = false),
        onNavigationRequest: (req) {
          final url = req.url.toLowerCase();
          if (url.contains('paystack.co/close') ||
              url.contains('callback') ||
              url.contains('success') ||
              url.contains('cancel')) {
            _triggerVerification();
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(checkoutUrl));
  }

  Future<void> _triggerVerification() async {
    if (_verifying) return;
    setState(() => _verifying = true);
    final ref = widget.data.paymentResponse?.transactionRef ?? '';
    try {
      final repo = RepositoryProvider.of<BookingRepository>(context);
      final paymentResult = await repo.verifyPayment(ref);
      if (!mounted) return;

      if (paymentResult.status == 'paid') {
        // Fetch full confirmed booking with QR
        final confirmed = await repo.getBooking(widget.data.bookingId);
        if (!mounted) return;
        final updatedData = widget.data.copyWith(
          paymentResponse: paymentResult,
          confirmedBooking: confirmed,
        );
        context.pushReplacement(AppRoutes.bookingConfirmed, extra: updatedData);
      } else {
        _showFailureSheet('Payment not confirmed. Status: ${paymentResult.status}', ref);
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('409')) {
        _showConflictSheet(ref);
      } else {
        _showFailureSheet('Verification failed: $msg', ref);
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _showConflictSheet(String transactionRef) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ConflictSheet(transactionRef: transactionRef),
    );
  }

  void _showFailureSheet(String message, String transactionRef) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ErrorSheet(message: message, transactionRef: transactionRef),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      onPopInvoked: (_) => _triggerVerification(),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              await _triggerVerification();
            },
          ),
          title: Text('Paystack Checkout',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.lock_rounded,
                    color: AppColors.success, size: 12),
                const SizedBox(width: 4),
                Text('Secure',
                    style: tt.labelSmall?.copyWith(
                        color: AppColors.success, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
        ),
        body: Stack(children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: isDark ? AppColors.darkBackground : AppColors.white,
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('Loading Paystack...',
                      style: tt.bodyMedium?.copyWith(color: AppColors.grey500)),
                ]),
              ),
            ),
          if (_verifying)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.white,
                      borderRadius: BorderRadius.circular(20)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('Verifying payment...',
                        style:
                            tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('Please wait while we confirm your payment.',
                        style: tt.bodySmall?.copyWith(color: AppColors.grey500),
                        textAlign: TextAlign.center),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

// ── Conflict sheet ────────────────────────────────────────────────────────────

class _ConflictSheet extends StatelessWidget {
  final String transactionRef;
  const _ConflictSheet({required this.transactionRef});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : AppColors.white;

    return Container(
      decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: AppColors.grey300, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 24),
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.12),
              shape: BoxShape.circle),
          child: const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 40),
        ),
        const SizedBox(height: 16),
        Text('Reservation Expired',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          'Your seats were booked by someone else during checkout. '
          'You will receive an automatic refund or contact support.',
          style: tt.bodyMedium?.copyWith(color: AppColors.grey500),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppColors.grey200,
              borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.receipt_long_rounded,
                color: AppColors.grey500, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              Text('Transaction Reference',
                  style: tt.labelSmall?.copyWith(color: AppColors.grey500)),
              Text(transactionRef,
                  style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            ])),
          ]),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go(AppRoutes.home);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            child: const Text('Back to Search',
                style: TextStyle(color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}

// ── Generic error sheet ───────────────────────────────────────────────────────

class _ErrorSheet extends StatelessWidget {
  final String message;
  final String transactionRef;
  const _ErrorSheet({required this.message, required this.transactionRef});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : AppColors.white;

    return Container(
      decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: AppColors.grey300, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 24),
        const Icon(Icons.warning_amber_rounded,
            color: Colors.orange, size: 48),
        const SizedBox(height: 16),
        Text('Payment Issue', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(message,
            style: tt.bodySmall?.copyWith(color: AppColors.grey500),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Ref: $transactionRef',
            style: tt.labelSmall?.copyWith(color: AppColors.grey400)),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(
              child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Retry'))),
          const SizedBox(width: 12),
          Expanded(
              child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go(AppRoutes.home);
                  },
                  child: const Text('Go Home'))),
        ]),
      ]),
    );
  }
}
"""

# ── PaymentProcessingPage (Mock only) ─────────────────────────────────────────

PAYMENT_PROCESSING = r"""import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/repositories/booking_repository.dart';
import '../models/booking_data.dart';

class PaymentProcessingPage extends StatefulWidget {
  final BookingData data;
  const PaymentProcessingPage({super.key, required this.data});
  @override
  State<PaymentProcessingPage> createState() => _PaymentProcessingPageState();
}

class _PaymentProcessingPageState extends State<PaymentProcessingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progress;
  String _statusText = 'Verifying mock payment...';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500));
    _progress = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _finalizeMock();
      }
    });
  }

  Future<void> _finalizeMock() async {
    setState(() => _statusText = 'Fetching your ticket...');
    try {
      final repo = RepositoryProvider.of<BookingRepository>(context);
      final confirmed = await repo.getBooking(widget.data.bookingId);
      if (!mounted) return;
      final updatedData = widget.data.copyWith(confirmedBooking: confirmed);
      context.pushReplacement(AppRoutes.bookingConfirmed, extra: updatedData);
    } catch (_) {
      if (!mounted) return;
      // Still navigate even if getBooking fails
      context.pushReplacement(AppRoutes.bookingConfirmed, extra: widget.data);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: cs.primary.withOpacity(0.3),
                        blurRadius: 24, offset: const Offset(0, 8))
                  ],
                ),
                child: const Icon(Icons.science_rounded,
                    color: Colors.white, size: 48),
              ),
              const SizedBox(height: 32),
              Text('Processing Payment',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(_statusText,
                  style: tt.bodyMedium?.copyWith(color: AppColors.grey500),
                  textAlign: TextAlign.center),
              const SizedBox(height: 32),
              AnimatedBuilder(
                animation: _progress,
                builder: (_, __) => Column(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                        value: _progress.value, minHeight: 6),
                  ),
                  const SizedBox(height: 8),
                  Text('${(_progress.value * 100).toInt()}%',
                      style: tt.bodySmall?.copyWith(
                          color: AppColors.grey500,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
"""

w("payment_page.dart", PAYMENT_PAGE)
w("paystack_webview_page.dart", PAYSTACK_WEBVIEW)
w("payment_processing_page.dart", PAYMENT_PROCESSING)
print("Done writing payment pages!")
