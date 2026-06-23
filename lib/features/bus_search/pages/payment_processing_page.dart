import 'package:flutter/material.dart';
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
                    BoxShadow(color: cs.primary.withValues(alpha: 0.3),
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
                builder: (_, _) => Column(children: [
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
