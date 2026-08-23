import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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
      onPopInvokedWithResult: (_, result) => _triggerVerification(),
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
                  color: AppColors.success.withValues(alpha:0.12),
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

class _ConflictSheet extends StatefulWidget {
  final String transactionRef;
  const _ConflictSheet({required this.transactionRef});

  @override
  State<_ConflictSheet> createState() => _ConflictSheetState();
}

class _ConflictSheetState extends State<_ConflictSheet> {
  bool _isRequesting = false;
  bool _refunded = false;
  String? _error;

  Future<void> _requestRefund() async {
    setState(() {
      _isRequesting = true;
      _error = null;
    });
    try {
      final repo = RepositoryProvider.of<BookingRepository>(context);
      final result = await repo.requestRefund(widget.transactionRef);
      if (!mounted) return;
      setState(() => _refunded = result.status == 'refunded');
    } catch (e) {
      if (!mounted) return;
      String msg = 'Refund request failed. Please contact support.';
      if (e is DioException) {
        final data = e.response?.data;
        if (data is Map && data['detail'] != null) {
          msg = data['detail'].toString();
        }
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

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
              color: (_refunded ? AppColors.success : AppColors.error)
                  .withValues(alpha:0.12),
              shape: BoxShape.circle),
          child: Icon(
              _refunded
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              color: _refunded ? AppColors.success : AppColors.error,
              size: 40),
        ),
        const SizedBox(height: 16),
        Text(_refunded ? 'Refund Processed' : 'Reservation Expired',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(
          _refunded
              ? 'Your payment has been refunded. It may take a few days to '
                'reflect on your card or account.'
              : 'Your seats were booked by someone else during checkout, '
                'but your payment went through. Request a refund below.',
          style: tt.bodyMedium?.copyWith(color: AppColors.grey500),
          textAlign: TextAlign.center,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!,
              style: tt.bodySmall?.copyWith(color: AppColors.error),
              textAlign: TextAlign.center),
        ],
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
              Text(widget.transactionRef,
                  style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            ])),
          ]),
        ),
        const SizedBox(height: 24),
        if (!_refunded)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isRequesting ? null : _requestRefund,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: _isRequesting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Request Refund',
                      style: TextStyle(color: Colors.white)),
            ),
          ),
        if (!_refunded) const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isRequesting
                ? null
                : () {
                    Navigator.of(context).pop();
                    context.go(AppRoutes.home);
                  },
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            child: const Text('Back to Search'),
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
