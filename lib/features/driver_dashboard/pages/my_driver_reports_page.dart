import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/repositories/driver_repository.dart';
import '../models/driver_report_model.dart';

class MyDriverReportsPage extends StatefulWidget {
  const MyDriverReportsPage({super.key});

  @override
  State<MyDriverReportsPage> createState() => _MyDriverReportsPageState();
}

class _MyDriverReportsPageState extends State<MyDriverReportsPage> {
  List<DriverReportModel> _reports = [];
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
      final repo = RepositoryProvider.of<DriverRepository>(context);
      final reports = await repo.listReports();
      if (mounted) setState(() => _reports = reports);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('My Reports', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await context.push<bool>(AppRoutes.submitDriverReport);
          if (added == true) _load();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Report'),
      ),
      body: _isLoading
          ? _buildSkeleton(isDark)
          : _error != null
              ? _buildError(tt)
              : _reports.isEmpty
                  ? _buildEmpty(tt, isDark)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: _reports.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _ReportCard(
                          report: _reports[i],
                          isDark: isDark,
                          tt: tt,
                        ),
                      ),
                    ),
    );
  }

  Widget _buildSkeleton(bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => Container(
        height: 90,
        decoration: BoxDecoration(
          color: isDark ? AppColors.grey800 : AppColors.grey200,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _buildError(TextTheme tt) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 48),
          const SizedBox(height: 12),
          Text('Failed to load reports', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(TextTheme tt, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 64,
            color: isDark ? AppColors.grey700 : AppColors.grey300,
          ),
          const SizedBox(height: 12),
          Text('No reports yet', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'Tap the button below to report a vehicle or route issue.',
            style: tt.bodySmall?.copyWith(color: AppColors.grey500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.isDark, required this.tt});
  final DriverReportModel report;
  final bool isDark;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final card = isDark ? AppColors.darkSurface : AppColors.white;
    final border = isDark ? AppColors.darkOutline : AppColors.lightOutline;
    final subtle = isDark ? AppColors.darkOnSurfaceVariant : AppColors.lightOnSurfaceVariant;

    final statusColor = switch (report.status) {
      'resolved' => AppColors.success,
      'reviewed' => const Color(0xFF3B82F6),
      _ => const Color(0xFFF59E0B),
    };

    final categoryIcon = switch (report.category) {
      'vehicle' => Icons.directions_bus_rounded,
      'route' => Icons.route_rounded,
      _ => Icons.report_problem_rounded,
    };

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(categoryIcon, size: 18, color: statusColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  report.subject,
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _StatusBadge(status: report.status),
            ],
          ),
          if (report.tripOrigin != null && report.tripDestination != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.route_rounded, size: 13, color: subtle),
                const SizedBox(width: 4),
                Text(
                  '${report.tripOrigin} → ${report.tripDestination}',
                  style: tt.bodySmall?.copyWith(color: subtle),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text(
            report.description,
            style: tt.bodySmall?.copyWith(color: subtle),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (report.adminNote != null && report.adminNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.grey800 : AppColors.grey100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.admin_panel_settings_rounded, size: 14, color: subtle),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      report.adminNote!,
                      style: tt.bodySmall?.copyWith(
                        color: subtle,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _fmtDt(report.createdAt),
            style: tt.bodySmall?.copyWith(color: subtle, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _fmtDt(DateTime dt) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'resolved' => AppColors.success,
      'reviewed' => const Color(0xFF3B82F6),
      _ => const Color(0xFFF59E0B),
    };
    final label = switch (status) {
      'resolved' => 'Resolved',
      'reviewed' => 'Reviewed',
      _ => 'Pending',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
