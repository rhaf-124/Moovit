class DriverReportModel {
  final String id;
  final String? tripId;
  final String category; // vehicle, route, other
  final String subject;
  final String description;
  final String status; // pending, reviewed, resolved
  final String? adminNote;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final String? tripOrigin;
  final String? tripDestination;
  final DateTime? departureTime;

  const DriverReportModel({
    required this.id,
    this.tripId,
    required this.category,
    required this.subject,
    required this.description,
    required this.status,
    this.adminNote,
    this.reviewedAt,
    required this.createdAt,
    this.tripOrigin,
    this.tripDestination,
    this.departureTime,
  });

  factory DriverReportModel.fromJson(Map<String, dynamic> json) {
    return DriverReportModel(
      id: json['id'] as String,
      tripId: json['trip_id'] as String?,
      category: json['category'] as String? ?? 'other',
      subject: json['subject'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      adminNote: json['admin_note'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.tryParse(json['reviewed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      tripOrigin: json['trip_origin'] as String?,
      tripDestination: json['trip_destination'] as String?,
      departureTime: json['departure_time'] != null
          ? DateTime.tryParse(json['departure_time'] as String)
          : null,
    );
  }
}
