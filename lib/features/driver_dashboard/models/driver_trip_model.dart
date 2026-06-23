class DriverTripModel {
  final String id;
  final String busId;
  final String routeId;
  final String driverId;
  final DateTime departureTime;
  final DateTime? arrivalTime;
  final double fare;
  final String status;
  final int availableSeats;
  final DateTime createdAt;
  final double currentLatitude;
  final double currentLongitude;
  final String driverName;
  final String busModel;
  final String busPlate;
  final String? busImageUrl;
  final String routeOrigin;
  final String routeDestination;
  final double routeDistanceKm;
  final int routeDurationMinutes;

  DriverTripModel({
    required this.id,
    required this.busId,
    required this.routeId,
    required this.driverId,
    required this.departureTime,
    this.arrivalTime,
    required this.fare,
    required this.status,
    required this.availableSeats,
    required this.createdAt,
    required this.currentLatitude,
    required this.currentLongitude,
    required this.driverName,
    required this.busModel,
    required this.busPlate,
    this.busImageUrl,
    required this.routeOrigin,
    required this.routeDestination,
    required this.routeDistanceKm,
    required this.routeDurationMinutes,
  });

  factory DriverTripModel.fromJson(Map<String, dynamic> json) {
    return DriverTripModel(
      id: json['id'] as String? ?? '',
      busId: json['bus_id'] as String? ?? '',
      routeId: json['route_id'] as String? ?? '',
      driverId: json['driver_id'] as String? ?? '',
      departureTime: json['departure_time'] != null
          ? DateTime.parse(json['departure_time'] as String)
          : DateTime.now(),
      arrivalTime: json['arrival_time'] != null
          ? DateTime.parse(json['arrival_time'] as String)
          : null,
      fare: double.tryParse(json['fare']?.toString() ?? '0') ?? 0.0,
      status: json['status'] as String? ?? '',
      availableSeats: json['available_seats'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      currentLatitude: double.tryParse(json['current_latitude']?.toString() ?? '0') ?? 0.0,
      currentLongitude: double.tryParse(json['current_longitude']?.toString() ?? '0') ?? 0.0,
      driverName: json['driver_name'] as String? ?? '',
      busModel: json['bus_model'] as String? ?? '',
      busPlate: json['bus_plate'] as String? ?? '',
      busImageUrl: json['bus_image'] as String?,
      routeOrigin: json['route_origin'] as String? ?? '',
      routeDestination: json['route_destination'] as String? ?? '',
      routeDistanceKm: double.tryParse(json['route_distance_km']?.toString() ?? '0') ?? 0.0,
      routeDurationMinutes: json['route_duration_minutes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bus_id': busId,
      'route_id': routeId,
      'driver_id': driverId,
      'departure_time': departureTime.toIso8601String(),
      'arrival_time': arrivalTime?.toIso8601String(),
      'fare': fare.toString(),
      'status': status,
      'available_seats': availableSeats,
      'created_at': createdAt.toIso8601String(),
      'current_latitude': currentLatitude,
      'current_longitude': currentLongitude,
      'driver_name': driverName,
      'bus_model': busModel,
      'bus_plate': busPlate,
      'bus_image': busImageUrl,
      'route_origin': routeOrigin,
      'route_destination': routeDestination,
      'route_distance_km': routeDistanceKm,
      'route_duration_minutes': routeDurationMinutes,
    };
  }

  DriverTripModel copyWith({
    String? id,
    String? busId,
    String? routeId,
    String? driverId,
    DateTime? departureTime,
    DateTime? arrivalTime,
    double? fare,
    String? status,
    int? availableSeats,
    DateTime? createdAt,
    double? currentLatitude,
    double? currentLongitude,
    String? driverName,
    String? busModel,
    String? busPlate,
    String? busImageUrl,
    String? routeOrigin,
    String? routeDestination,
    double? routeDistanceKm,
    int? routeDurationMinutes,
  }) {
    return DriverTripModel(
      id: id ?? this.id,
      busId: busId ?? this.busId,
      routeId: routeId ?? this.routeId,
      driverId: driverId ?? this.driverId,
      departureTime: departureTime ?? this.departureTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      fare: fare ?? this.fare,
      status: status ?? this.status,
      availableSeats: availableSeats ?? this.availableSeats,
      createdAt: createdAt ?? this.createdAt,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      driverName: driverName ?? this.driverName,
      busModel: busModel ?? this.busModel,
      busPlate: busPlate ?? this.busPlate,
      busImageUrl: busImageUrl ?? this.busImageUrl,
      routeOrigin: routeOrigin ?? this.routeOrigin,
      routeDestination: routeDestination ?? this.routeDestination,
      routeDistanceKm: routeDistanceKm ?? this.routeDistanceKm,
      routeDurationMinutes: routeDurationMinutes ?? this.routeDurationMinutes,
    );
  }
}
