class TripResponse {
  final String id;
  final String origin;
  final String destination;
  final double fare;
  final DateTime departureTime;
  final DateTime? arrivalTime;
  final int availableSeats;
  final String status;
  final String busModel;
  final String busPlate;
  final String? busImage;

  TripResponse({
    required this.id,
    required this.origin,
    required this.destination,
    required this.fare,
    required this.departureTime,
    this.arrivalTime,
    required this.availableSeats,
    required this.status,
    required this.busModel,
    required this.busPlate,
    this.busImage,
  });

  factory TripResponse.fromJson(Map<String, dynamic> json) {
    return TripResponse(
      id: json['id'] as String? ?? '',
      origin: json['origin'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      fare: double.tryParse(json['fare']?.toString() ?? '0') ?? 0.0,
      departureTime: json['departure_time'] != null
          ? DateTime.parse(json['departure_time'] as String)
          : DateTime.now(),
      arrivalTime: json['arrival_time'] != null
          ? DateTime.parse(json['arrival_time'] as String)
          : null,
      availableSeats: json['available_seats'] as int? ?? 0,
      status: json['status'] as String? ?? '',
      busModel: json['bus_model'] as String? ?? '',
      busPlate: json['bus_plate'] as String? ?? '',
      busImage: json['bus_image'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'origin': origin,
      'destination': destination,
      'fare': fare.toString(),
      'departure_time': departureTime.toIso8601String(),
      'arrival_time': arrivalTime?.toIso8601String(),
      'available_seats': availableSeats,
      'status': status,
      'bus_model': busModel,
      'bus_plate': busPlate,
      'bus_image': busImage,
    };
  }
}
