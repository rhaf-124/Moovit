enum SeatStatus { available, reserved, booked }

enum SeatGender { male, female, other }

class SeatInfo {
  final int number;
  final SeatStatus status;
  final SeatGender? gender;

  const SeatInfo({
    required this.number,
    required this.status,
    this.gender,
  });
}

class BusModel {
  final String id;
  final String name;
  final String busNumber;
  final double rating;
  final String departureTime;
  final String arrivalTime;
  final String duration;
  final int distanceKm;
  final double pricePerSeat;
  final int totalSeats;
  final List<String> amenities; // 'wifi' | 'ac' | 'food' | 'charging'
  final List<String> tags;
  final List<SeatInfo> prePopulatedSeats;
  final String? imageUrl;
  final String origin;
  final String destination;

  const BusModel({
    required this.id,
    required this.name,
    required this.busNumber,
    required this.rating,
    required this.departureTime,
    required this.arrivalTime,
    required this.duration,
    required this.distanceKm,
    required this.pricePerSeat,
    required this.totalSeats,
    required this.amenities,
    required this.tags,
    required this.prePopulatedSeats,
    this.imageUrl,
    this.origin = '',
    this.destination = '',
  });

  int get availableSeats => totalSeats - prePopulatedSeats.length;

  BusModel copyWith({
    String? id,
    String? name,
    String? busNumber,
    double? rating,
    String? departureTime,
    String? arrivalTime,
    String? duration,
    int? distanceKm,
    double? pricePerSeat,
    int? totalSeats,
    List<String>? amenities,
    List<String>? tags,
    List<SeatInfo>? prePopulatedSeats,
    String? imageUrl,
    String? origin,
    String? destination,
  }) {
    return BusModel(
      id: id ?? this.id,
      name: name ?? this.name,
      busNumber: busNumber ?? this.busNumber,
      rating: rating ?? this.rating,
      departureTime: departureTime ?? this.departureTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      duration: duration ?? this.duration,
      distanceKm: distanceKm ?? this.distanceKm,
      pricePerSeat: pricePerSeat ?? this.pricePerSeat,
      totalSeats: totalSeats ?? this.totalSeats,
      amenities: amenities ?? this.amenities,
      tags: tags ?? this.tags,
      prePopulatedSeats: prePopulatedSeats ?? this.prePopulatedSeats,
      imageUrl: imageUrl ?? this.imageUrl,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
    );
  }
}

