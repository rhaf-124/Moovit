class PopularRouteModel {
  final String origin;
  final String destination;
  final double baseFare;
  final double? distanceKm;
  final int bookingCount;

  const PopularRouteModel({
    required this.origin,
    required this.destination,
    required this.baseFare,
    this.distanceKm,
    this.bookingCount = 0,
  });

  factory PopularRouteModel.fromJson(Map<String, dynamic> json) {
    return PopularRouteModel(
      origin: json['origin'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      baseFare: (json['base_fare'] as num?)?.toDouble() ?? 0.0,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      bookingCount: json['booking_count'] as int? ?? 0,
    );
  }
}
