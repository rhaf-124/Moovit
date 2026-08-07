import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_formatter.dart';
import '../domain/repositories/review_repository.dart';
import '../models/complaint_model.dart';

class SubmitComplaintPage extends StatefulWidget {
  final String tripId;
  final String tripOrigin;
  final String tripDestination;
  final DateTime? departureTime;

  const SubmitComplaintPage({
    super.key,
    required this.tripId,
    required this.tripOrigin,
    required this.tripDestination,
    this.departureTime,
  });

  @override
  State<SubmitComplaintPage> createState() => _SubmitComplaintPageState();
}

class _SubmitComplaintPageState extends State<SubmitComplaintPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  String? _selectedSubject;
  bool _isSubmitting = false;
  bool _checking = true;
  ComplaintModel? _existingComplaint;

  static const _subjects = [
    'Driver Behavior',
    'Vehicle Condition',
    'Late Departure / No-show',
    'Safety Concern',
    'Ticketing Issue',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _checkExisting();
  }

  Future<void> _checkExisting() async {
    try {
      final repo = RepositoryProvider.of<ReviewRepository>(context);
      final results = await repo.listComplaints(tripId: widget.tripId);
      if (!mounted) return;
      setState(() {
        _existingComplaint = results.isNotEmpty ? results.first : null;
        _checking = false;
      });
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  String _fmtDt(DateTime d) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year}  $h:$m';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final repo = RepositoryProvider.of<ReviewRepository>(context);
      await repo.submitComplaint(
        tripId: widget.tripId,
        subject: _selectedSubject!,
        description: _descriptionController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your complaint has been submitted successfully.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      String message = friendlyError(e);
      if (e is DioException) {
        if (e.response?.statusCode == 409) {
          message = 'You have already reported an issue for this trip.';
          // Refresh so the "already reported" card shows
          _checkExisting();
        } else if (e.response?.statusCode == 403) {
          message =
              'You can only report issues for trips you have a confirmed or boarded booking for.';
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.darkOutline : AppColors.lightOutline;
    final subtle =
        isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Report Issue',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : _existingComplaint != null
              ? _AlreadyReportedView(
                  complaint: _existingComplaint!,
                  isDark: isDark,
                  border: border,
                  subtle: subtle,
                  fmtDt: _fmtDt,
                )
              : _buildForm(context, tt, cs, isDark, border, subtle),
    );
  }

  Widget _buildForm(
    BuildContext context,
    TextTheme tt,
    ColorScheme cs,
    bool isDark,
    Color border,
    Color subtle,
  ) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // ── Trip info card ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.directions_bus_rounded,
                        color: cs.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text('Trip Details',
                      style: tt.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.tripOrigin,
                            style: tt.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        Text('From',
                            style: tt.bodySmall?.copyWith(color: subtle)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded,
                      color: cs.primary, size: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(widget.tripDestination,
                            style: tt.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                            textAlign: TextAlign.end),
                        Text('To',
                            style: tt.bodySmall?.copyWith(color: subtle)),
                      ],
                    ),
                  ),
                ]),
                if (widget.departureTime != null) ...[
                  const SizedBox(height: 10),
                  Divider(height: 1, color: border),
                  const SizedBox(height: 10),
                  Row(children: [
                    Icon(Icons.schedule_rounded, size: 14, color: subtle),
                    const SizedBox(width: 6),
                    Text(_fmtDt(widget.departureTime!),
                        style: tt.bodySmall?.copyWith(color: subtle)),
                  ]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Subject ─────────────────────────────────────────────────
          Text('Subject',
              style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedSubject,
            decoration: InputDecoration(
              hintText: 'Select a subject',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.primary, width: 2),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: _subjects
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _selectedSubject = v),
            validator: (v) =>
                v == null || v.isEmpty ? 'Please select a subject' : null,
          ),
          const SizedBox(height: 20),

          // ── Description ─────────────────────────────────────────────
          Text('Description',
              style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            maxLines: 5,
            maxLength: 2000,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText:
                  'Please describe the issue in detail (minimum 10 characters)...',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: cs.primary, width: 2),
              ),
              alignLabelWithHint: true,
              contentPadding: const EdgeInsets.all(16),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Please describe the issue';
              }
              if (v.trim().length < 10) {
                return 'Description must be at least 10 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Your complaint will be reviewed by our team within 24-48 hours.',
            style: tt.bodySmall?.copyWith(color: subtle),
          ),
          const SizedBox(height: 28),

          // ── Submit button ────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                backgroundColor: AppColors.error,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  : const Text(
                      'Submit Complaint',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlreadyReportedView extends StatelessWidget {
  const _AlreadyReportedView({
    required this.complaint,
    required this.isDark,
    required this.border,
    required this.subtle,
    required this.fmtDt,
  });

  final ComplaintModel complaint;
  final bool isDark;
  final Color border;
  final Color subtle;
  final String Function(DateTime) fmtDt;

  Color get _statusColor => switch (complaint.status) {
        'resolved' => AppColors.success,
        'reviewed' => AppColors.primary,
        _ => AppColors.warning,
      };

  String get _statusLabel => switch (complaint.status) {
        'resolved' => 'Resolved',
        'reviewed' => 'Under Review',
        _ => 'Pending',
      };

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        // ── Already reported banner ─────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.error, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Issue Already Reported',
                        style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.error)),
                    const SizedBox(height: 2),
                    Text(
                        'You have already submitted a complaint for this trip.',
                        style: tt.bodySmall?.copyWith(color: subtle)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Submitted complaint details ──────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Your Complaint',
                      style:
                          tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel,
                      style: tt.labelSmall?.copyWith(
                          color: _statusColor, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text('Subject', style: tt.labelMedium?.copyWith(color: subtle)),
              const SizedBox(height: 2),
              Text(complaint.subject,
                  style:
                      tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Text('Description',
                  style: tt.labelMedium?.copyWith(color: subtle)),
              const SizedBox(height: 2),
              Text(complaint.description, style: tt.bodyMedium),
              if (complaint.adminNote != null &&
                  complaint.adminNote!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Divider(height: 1, color: border),
                const SizedBox(height: 14),
                Text('Admin Response',
                    style: tt.labelMedium?.copyWith(color: subtle)),
                const SizedBox(height: 2),
                Text(complaint.adminNote!, style: tt.bodyMedium),
              ],
              const SizedBox(height: 14),
              Divider(height: 1, color: border),
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.schedule_rounded, size: 13, color: subtle),
                const SizedBox(width: 5),
                Text('Submitted ${fmtDt(complaint.createdAt)}',
                    style: tt.bodySmall?.copyWith(color: subtle)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 28),

        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            side: BorderSide(color: cs.primary),
          ),
          child: const Text('Go Back'),
        ),
      ],
    );
  }
}
