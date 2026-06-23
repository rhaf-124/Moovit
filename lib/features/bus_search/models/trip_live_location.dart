class TripLiveLocation {
  final String tripId;
  final String status;
  final double? currentLatitude;
  final double? currentLongitude;
  final String origin;
  final String destination;
  final DateTime departureTime;
  final String busModel;
  final String busPlate;

  const TripLiveLocation({
    required this.tripId,
    required this.status,
    this.currentLatitude,
    this.currentLongitude,
    required this.origin,
    required this.destination,
    required this.departureTime,
    required this.busModel,
    required this.busPlate,
  });

  bool get hasLocation =>
      currentLatitude != null &&
      currentLongitude != null &&
      (currentLatitude! != 0.0 || currentLongitude! != 0.0);

  factory TripLiveLocation.fromJson(Map<String, dynamic> json) {
    return TripLiveLocation(
      tripId: json['trip_id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      currentLatitude: json['current_latitude'] != null
          ? double.tryParse(json['current_latitude'].toString())
          : null,
      currentLongitude: json['current_longitude'] != null
          ? double.tryParse(json['current_longitude'].toString())
          : null,
      origin: json['route_origin'] as String? ?? '',
      destination: json['route_destination'] as String? ?? '',
      departureTime: json['departure_time'] != null
          ? DateTime.parse(json['departure_time'] as String)
          : DateTime.now(),
      busModel: json['bus_model'] as String? ?? '',
      busPlate: json['bus_plate'] as String? ?? '',
    );
  }
}
