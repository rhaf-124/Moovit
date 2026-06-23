import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/repositories/driver_repository.dart';
import '../models/driver_trip_model.dart';

class SubmitDriverReportPage extends StatefulWidget {
  final DriverTripModel? preselectedTrip;

  const SubmitDriverReportPage({super.key, this.preselectedTrip});

  @override
  State<SubmitDriverReportPage> createState() => _SubmitDriverReportPageState();
}

class _SubmitDriverReportPageState extends State<SubmitDriverReportPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  String _category = 'vehicle';
  String? _subject;
  bool _isSubmitting = false;

  static const _vehicleSubjects = [
    'Tyre Problem',
    'Brake Issue',
    'Engine Overheating',
    'Mechanical Breakdown',
    'AC / Electrical Fault',
    'Other Vehicle Issue',
  ];

  static const _routeSubjects = [
    'Road Obstruction',
    'Road Damage / Pothole',
    'Flooded Road',
    'Traffic Incident',
    'Route Closure',
    'Other Route Issue',
  ];

  static const _otherSubjects = [
    'Passenger Misconduct',
    'Terminal Issue',
    'Schedule Problem',
    'Other',
  ];

  List<String> get _subjects => switch (_category) {
        'vehicle' => _vehicleSubjects,
        'route' => _routeSubjects,
        _ => _otherSubjects,
      };

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    final repo = RepositoryProvider.of<DriverRepository>(context);
    try {
      await repo.submitReport(
        category: _category,
        subject: _subject!,
        description: _descriptionController.text.trim(),
        tripId: widget.preselectedTrip?.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyError(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('not found')) return 'Trip not found. Please try again.';
    if (msg.contains('network') || msg.contains('connection')) {
      return 'No connection. Check your internet and try again.';
    }
    return 'Failed to submit report. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Report Issue',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Trip info banner
            if (widget.preselectedTrip != null) ...[
              _TripBanner(trip: widget.preselectedTrip!, isDark: isDark, tt: tt),
              const SizedBox(height: 24),
            ],

            // Category
            Text('Category', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              children: [
                _CategoryChip(
                  label: 'Vehicle',
                  icon: Icons.directions_bus_rounded,
                  selected: _category == 'vehicle',
                  onTap: () => setState(() {
                    _category = 'vehicle';
                    _subject = null;
                  }),
                ),
                const SizedBox(width: 10),
                _CategoryChip(
                  label: 'Route',
                  icon: Icons.route_rounded,
                  selected: _category == 'route',
                  onTap: () => setState(() {
                    _category = 'route';
                    _subject = null;
                  }),
                ),
                const SizedBox(width: 10),
                _CategoryChip(
                  label: 'Other',
                  icon: Icons.more_horiz_rounded,
                  selected: _category == 'other',
                  onTap: () => setState(() {
                    _category = 'other';
                    _subject = null;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Subject
            Text('Subject', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _subject,
              decoration: InputDecoration(
                hintText: 'Select issue type',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              items: _subjects
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _subject = v),
              validator: (v) => v == null ? 'Please select a subject' : null,
            ),
            const SizedBox(height: 24),

            // Description
            Text('Description', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            TextFormField(
              controller: _descriptionController,
              maxLines: 5,
              maxLength: 2000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Describe the issue in detail…',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                alignLabelWithHint: true,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Description is required';
                if (v.trim().length < 10) return 'Please provide more detail (min 10 characters)';
                return null;
              },
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripBanner extends StatelessWidget {
  const _TripBanner({required this.trip, required this.isDark, required this.tt});
  final DriverTripModel trip;
  final bool isDark;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.directions_bus_rounded, color: cs.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${trip.routeOrigin} → ${trip.routeDestination}',
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  _fmtDt(trip.departureTime),
                  style: tt.bodySmall?.copyWith(color: isDark ? AppColors.grey400 : AppColors.grey600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDt(DateTime dt) {
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day} ${months[dt.month - 1]}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? cs.primary : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
