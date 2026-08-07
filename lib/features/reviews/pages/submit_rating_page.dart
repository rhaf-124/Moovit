import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_formatter.dart';
import '../domain/repositories/review_repository.dart';
import '../models/rating_model.dart';

class SubmitRatingPage extends StatefulWidget {
  final String tripId;
  final String tripOrigin;
  final String tripDestination;
  final String? driverName;
  final DateTime? departureTime;

  const SubmitRatingPage({
    super.key,
    required this.tripId,
    required this.tripOrigin,
    required this.tripDestination,
    this.driverName,
    this.departureTime,
  });

  @override
  State<SubmitRatingPage> createState() => _SubmitRatingPageState();
}

class _SubmitRatingPageState extends State<SubmitRatingPage> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();

  int _tripRating = 0;
  int _driverRating = 0;
  bool _isSubmitting = false;
  bool _checking = true;
  RatingModel? _existingRating;

  @override
  void initState() {
    super.initState();
    _checkExisting();
  }

  Future<void> _checkExisting() async {
    try {
      final repo = RepositoryProvider.of<ReviewRepository>(context);
      final results = await repo.listRatings(tripId: widget.tripId);
      if (!mounted) return;
      setState(() {
        _existingRating = results.isNotEmpty ? results.first : null;
        _checking = false;
      });
    } catch (_) {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
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
    if (_tripRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please rate your trip experience.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    if (_driverRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please rate the driver.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final repo = RepositoryProvider.of<ReviewRepository>(context);
      await repo.submitRating(
        tripId: widget.tripId,
        tripRating: _tripRating,
        driverRating: _driverRating,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thank you for your rating!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      String message = friendlyError(e);
      if (e is DioException) {
        if (e.response?.statusCode == 409) {
          message = 'You have already rated this trip.';
          // Refresh so the "already rated" card shows
          _checkExisting();
        } else if (e.response?.statusCode == 403) {
          message = 'You can only rate trips after you have boarded.';
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
          'Rate Your Trip',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : _existingRating != null
              ? _AlreadyRatedView(
                  rating: _existingRating!,
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
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.star_rounded,
                        color: Color(0xFFF59E0B), size: 18),
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
                if (widget.driverName != null &&
                    widget.driverName!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Divider(height: 1, color: border),
                  const SizedBox(height: 10),
                  Row(children: [
                    Icon(Icons.person_rounded, size: 14, color: subtle),
                    const SizedBox(width: 6),
                    Text('Driver: ${widget.driverName}',
                        style: tt.bodySmall?.copyWith(color: subtle)),
                  ]),
                ],
                if (widget.departureTime != null) ...[
                  const SizedBox(height: 6),
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
          const SizedBox(height: 24),

          // ── Trip Experience rating ───────────────────────────────────
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
                Text('Trip Experience',
                    style:
                        tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('How was the overall trip?',
                    style: tt.bodySmall?.copyWith(color: subtle)),
                const SizedBox(height: 14),
                _StarRow(
                  rating: _tripRating,
                  onChanged: (v) => setState(() => _tripRating = v),
                ),
                if (_tripRating > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    _ratingLabel(_tripRating),
                    style: tt.bodySmall?.copyWith(
                      color: _ratingColor(_tripRating),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Driver rating ────────────────────────────────────────────
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
                Text('Driver',
                    style:
                        tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('How was the driver?',
                    style: tt.bodySmall?.copyWith(color: subtle)),
                const SizedBox(height: 14),
                _StarRow(
                  rating: _driverRating,
                  onChanged: (v) => setState(() => _driverRating = v),
                ),
                if (_driverRating > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    _ratingLabel(_driverRating),
                    style: tt.bodySmall?.copyWith(
                      color: _ratingColor(_driverRating),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Optional comment ─────────────────────────────────────────
          Text('Comment (optional)',
              style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _commentController,
            maxLines: 4,
            maxLength: 500,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'Share any additional thoughts...',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
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
              if (v != null && v.trim().length > 500) {
                return 'Comment must be at most 500 characters';
              }
              return null;
            },
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
                backgroundColor: const Color(0xFFF59E0B),
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
                      'Submit Rating',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _ratingLabel(int r) => switch (r) {
        1 => 'Poor',
        2 => 'Fair',
        3 => 'Good',
        4 => 'Very Good',
        5 => 'Excellent',
        _ => '',
      };

  Color _ratingColor(int r) => switch (r) {
        1 => AppColors.error,
        2 => AppColors.secondary,
        3 => AppColors.warning,
        4 => AppColors.success,
        5 => AppColors.primary,
        _ => AppColors.grey400,
      };
}

class _AlreadyRatedView extends StatelessWidget {
  const _AlreadyRatedView({
    required this.rating,
    required this.isDark,
    required this.border,
    required this.subtle,
    required this.fmtDt,
  });

  final RatingModel rating;
  final bool isDark;
  final Color border;
  final Color subtle;
  final String Function(DateTime) fmtDt;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      children: [
        // ── Already rated banner ────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFFF59E0B), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Already Rated',
                        style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFF59E0B))),
                    const SizedBox(height: 2),
                    Text('You have already submitted a rating for this trip.',
                        style: tt.bodySmall?.copyWith(color: subtle)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Submitted rating details ─────────────────────────────────
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
              Text('Your Rating',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              _RatingRow(label: 'Trip Experience', value: rating.tripRating),
              const SizedBox(height: 10),
              _RatingRow(label: 'Driver', value: rating.driverRating),
              if (rating.comment != null && rating.comment!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Divider(height: 1, color: border),
                const SizedBox(height: 14),
                Text('Comment',
                    style: tt.labelMedium?.copyWith(color: subtle)),
                const SizedBox(height: 4),
                Text(rating.comment!, style: tt.bodyMedium),
              ],
              const SizedBox(height: 14),
              Divider(height: 1, color: border),
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.schedule_rounded, size: 13, color: subtle),
                const SizedBox(width: 5),
                Text('Submitted ${fmtDt(rating.createdAt)}',
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

class _RatingRow extends StatelessWidget {
  const _RatingRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Text(label, style: tt.bodyMedium)),
        Row(
          children: List.generate(5, (i) {
            return Icon(
              i < value ? Icons.star_rounded : Icons.star_outline_rounded,
              color: i < value ? const Color(0xFFF59E0B) : AppColors.grey300,
              size: 20,
            );
          }),
        ),
      ],
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating, required this.onChanged});

  final int rating;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final starIndex = i + 1;
        return GestureDetector(
          onTap: () => onChanged(starIndex),
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Icon(
              starIndex <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
              color: starIndex <= rating
                  ? const Color(0xFFF59E0B)
                  : AppColors.grey300,
              size: 40,
            ),
          ),
        );
      }),
    );
  }
}
