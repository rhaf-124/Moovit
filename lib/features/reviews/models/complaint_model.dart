class ComplaintModel {
  final String id;
  final String tripId;
  final String? driverId;
  final String subject;
  final String description;
  final String status; // pending, reviewed, resolved
  final String? adminNote;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final String? tripOrigin;
  final String? tripDestination;
  final String? driverName;
  final DateTime? departureTime;

  const ComplaintModel({
    required this.id,
    required this.tripId,
    this.driverId,
    required this.subject,
    required this.description,
    required this.status,
    this.adminNote,
    this.reviewedAt,
    required this.createdAt,
    this.tripOrigin,
    this.tripDestination,
    this.driverName,
    this.departureTime,
  });

  factory ComplaintModel.fromJson(Map<String, dynamic> json) {
    return ComplaintModel(
      id: json['id'] as String,
      tripId: json['trip_id'] as String? ?? '',
      driverId: json['driver_id'] as String?,
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
      driverName: json['driver_name'] as String?,
      departureTime: json['departure_time'] != null
          ? DateTime.tryParse(json['departure_time'] as String)
          : null,
    );
  }
}
