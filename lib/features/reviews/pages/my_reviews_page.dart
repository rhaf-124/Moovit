import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/repositories/review_repository.dart';
import '../models/complaint_model.dart';
import '../models/rating_model.dart';

class MyReviewsPage extends StatefulWidget {
  const MyReviewsPage({super.key});

  @override
  State<MyReviewsPage> createState() => _MyReviewsPageState();
}

class _MyReviewsPageState extends State<MyReviewsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<ComplaintModel>? _complaints;
  List<RatingModel>? _ratings;
  bool _loadingComplaints = true;
  bool _loadingRatings = true;
  String? _complaintsError;
  String? _ratingsError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadComplaints();
    _loadRatings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadComplaints() async {
    setState(() {
      _loadingComplaints = true;
      _complaintsError = null;
    });
    try {
      final repo = RepositoryProvider.of<ReviewRepository>(context);
      final data = await repo.listComplaints();
      if (mounted) setState(() => _complaints = data);
    } catch (e) {
      if (mounted) setState(() => _complaintsError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingComplaints = false);
    }
  }

  Future<void> _loadRatings() async {
    setState(() {
      _loadingRatings = true;
      _ratingsError = null;
    });
    try {
      final repo = RepositoryProvider.of<ReviewRepository>(context);
      final data = await repo.listRatings();
      if (mounted) setState(() => _ratings = data);
    } catch (e) {
      if (mounted) setState(() => _ratingsError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingRatings = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'My Reviews',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Complaints'),
            Tab(text: 'Ratings'),
          ],
          labelColor: cs.primary,
          indicatorColor: cs.primary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ComplaintsTab(
            complaints: _complaints,
            isLoading: _loadingComplaints,
            error: _complaintsError,
            onRetry: _loadComplaints,
          ),
          _RatingsTab(
            ratings: _ratings,
            isLoading: _loadingRatings,
            error: _ratingsError,
            onRetry: _loadRatings,
          ),
        ],
      ),
    );
  }
}

// ── Complaints Tab ────────────────────────────────────────────────────────────

class _ComplaintsTab extends StatelessWidget {
  const _ComplaintsTab({
    required this.complaints,
    required this.isLoading,
    required this.error,
    required this.onRetry,
  });

  final List<ComplaintModel>? complaints;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isLoading) return _ShimmerList(isDark: isDark);

    if (error != null) {
      return _ErrorView(message: error!, onRetry: onRetry, tt: tt);
    }

    final items = complaints ?? [];
    if (items.isEmpty) {
      return _EmptyState(
        icon: Icons.report_problem_outlined,
        title: 'No complaints yet',
        subtitle: 'When you submit a complaint it will appear here.',
        tt: tt,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _ComplaintCard(complaint: items[i]),
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({required this.complaint});

  final ComplaintModel complaint;

  Color _statusColor() => switch (complaint.status) {
        'reviewed' => AppColors.info,
        'resolved' => AppColors.success,
        _ => AppColors.warning,
      };

  String _statusLabel() => switch (complaint.status) {
        'reviewed' => 'Reviewed',
        'resolved' => 'Resolved',
        _ => 'Pending',
      };

  String _fmtDate(DateTime d) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.darkOutline : AppColors.lightOutline;
    final subtle =
        isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant;
    final statusColor = _statusColor();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                complaint.subject,
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _statusLabel(),
                style: tt.labelSmall?.copyWith(
                    color: statusColor, fontWeight: FontWeight.w700),
              ),
            ),
          ]),
          if (complaint.tripOrigin != null &&
              complaint.tripDestination != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.directions_bus_rounded, size: 14, color: subtle),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${complaint.tripOrigin}  →  ${complaint.tripDestination}',
                  style: tt.bodySmall?.copyWith(
                      color: subtle, fontWeight: FontWeight.w500),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.calendar_today_rounded, size: 13, color: subtle),
            const SizedBox(width: 6),
            Text(_fmtDate(complaint.createdAt),
                style: tt.bodySmall?.copyWith(color: subtle)),
          ]),
          if (complaint.adminNote != null &&
              complaint.adminNote!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceVariant
                    : AppColors.lightSurfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.admin_panel_settings_rounded,
                      size: 14, color: subtle),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      complaint.adminNote!,
                      style: tt.bodySmall?.copyWith(
                          color: subtle, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Ratings Tab ───────────────────────────────────────────────────────────────

class _RatingsTab extends StatelessWidget {
  const _RatingsTab({
    required this.ratings,
    required this.isLoading,
    required this.error,
    required this.onRetry,
  });

  final List<RatingModel>? ratings;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isLoading) return _ShimmerList(isDark: isDark);

    if (error != null) {
      return _ErrorView(message: error!, onRetry: onRetry, tt: tt);
    }

    final items = ratings ?? [];
    if (items.isEmpty) {
      return _EmptyState(
        icon: Icons.star_outline_rounded,
        title: 'No ratings yet',
        subtitle: 'Rate a trip after you have boarded and it will appear here.',
        tt: tt,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _RatingCard(rating: items[i]),
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.rating});

  final RatingModel rating;

  String _fmtDate(DateTime d) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year}  $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppColors.darkOutline : AppColors.lightOutline;
    final subtle =
        isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Route
          if (rating.tripOrigin != null && rating.tripDestination != null)
            Row(children: [
              Icon(Icons.directions_bus_rounded, size: 16, color: subtle),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${rating.tripOrigin}  →  ${rating.tripDestination}',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ]),

          // Departure date
          if (rating.departureTime != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              const SizedBox(width: 22),
              Text(_fmtDate(rating.departureTime!),
                  style: tt.bodySmall?.copyWith(color: subtle)),
            ]),
          ],

          const SizedBox(height: 12),
          Divider(height: 1, color: border),
          const SizedBox(height: 12),

          // Trip rating row
          _RatingRow(
            label: 'Trip',
            icon: Icons.directions_bus_outlined,
            rating: rating.tripRating,
            tt: tt,
            subtle: subtle,
          ),
          const SizedBox(height: 8),

          // Driver rating row
          _RatingRow(
            label: 'Driver',
            icon: Icons.person_outline_rounded,
            rating: rating.driverRating,
            tt: tt,
            subtle: subtle,
          ),

          // Comment
          if (rating.comment != null && rating.comment!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceVariant
                    : AppColors.lightSurfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.comment_outlined, size: 14, color: subtle),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rating.comment!,
                      style: tt.bodySmall?.copyWith(color: subtle),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.label,
    required this.icon,
    required this.rating,
    required this.tt,
    required this.subtle,
  });

  final String label;
  final IconData icon;
  final int rating;
  final TextTheme tt;
  final Color subtle;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: subtle),
      const SizedBox(width: 6),
      SizedBox(
        width: 52,
        child: Text(label,
            style: tt.bodySmall?.copyWith(color: subtle)),
      ),
      const SizedBox(width: 8),
      Row(
        children: List.generate(5, (i) {
          final filled = i < rating;
          return Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 18,
            color: filled ? const Color(0xFFF59E0B) : AppColors.grey300,
          );
        }),
      ),
      const SizedBox(width: 8),
      Text('$rating/5',
          style: tt.bodySmall?.copyWith(
              fontWeight: FontWeight.w600, color: subtle)),
    ]);
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _ShimmerList extends StatelessWidget {
  const _ShimmerList({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.grey800 : AppColors.grey200,
      highlightColor: isDark ? AppColors.grey700 : AppColors.grey100,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Container(
          height: 110,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tt,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.grey100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppColors.grey400),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(subtitle,
                style: tt.bodySmall?.copyWith(color: AppColors.grey500),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.tt,
  });

  final String message;
  final VoidCallback onRetry;
  final TextTheme tt;

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
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 40),
            ),
            const SizedBox(height: 16),
            Text('Could not load',
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
          ],
        ),
      ),
    );
  }
}
