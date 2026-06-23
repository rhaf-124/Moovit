class RatingModel {
  final String id;
  final String tripId;
  final String driverId;
  final int tripRating;
  final int driverRating;
  final String? comment;
  final DateTime createdAt;
  final String? tripOrigin;
  final String? tripDestination;
  final String? driverName;
  final DateTime? departureTime;

  const RatingModel({
    required this.id,
    required this.tripId,
    required this.driverId,
    required this.tripRating,
    required this.driverRating,
    this.comment,
    required this.createdAt,
    this.tripOrigin,
    this.tripDestination,
    this.driverName,
    this.departureTime,
  });

  factory RatingModel.fromJson(Map<String, dynamic> json) {
    return RatingModel(
      id: json['id'] as String,
      tripId: json['trip_id'] as String? ?? '',
      driverId: json['driver_id'] as String? ?? '',
      tripRating: json['trip_rating'] as int? ?? 1,
      driverRating: json['driver_rating'] as int? ?? 1,
      comment: json['comment'] as String?,
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
