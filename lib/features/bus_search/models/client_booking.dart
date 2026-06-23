class BookingSeatDetail {
  final String id;
  final String seatId;
  final String seatNumber;
  final String passengerName;
  final String contactNumber;
  final String gender;
  final bool hasLuggage;
  final String? luggageType;

  const BookingSeatDetail({
    required this.id,
    required this.seatId,
    required this.seatNumber,
    required this.passengerName,
    required this.contactNumber,
    required this.gender,
    required this.hasLuggage,
    this.luggageType,
  });

  factory BookingSeatDetail.fromJson(Map<String, dynamic> json) {
    return BookingSeatDetail(
      id: json['id'] as String? ?? '',
      seatId: json['seat_id'] as String? ?? '',
      seatNumber: json['seat_number'] as String? ?? '',
      passengerName: json['passenger_name'] as String? ?? '',
      contactNumber: json['contact_number'] as String? ?? '',
      gender: json['gender'] as String? ?? 'male',
      hasLuggage: json['has_luggage'] as bool? ?? false,
      luggageType: json['luggage_type'] as String?,
    );
  }
}

class ClientBooking {
  final String id;
  final String tripId;
  final List<BookingSeatDetail> seats;
  final String status;
  final double totalFare;
  final double discountAmount;
  final bool familyPackage;
  final int holdDurationMinutes;
  final DateTime? boardedAt;
  final DateTime expiresAt;
  final DateTime createdAt;
  final String? qrImageBase64;
  final String? scannedByDriverId;
  final String? scannedByDriverName;

  const ClientBooking({
    required this.id,
    required this.tripId,
    required this.seats,
    required this.status,
    required this.totalFare,
    this.discountAmount = 0.0,
    required this.familyPackage,
    required this.holdDurationMinutes,
    this.boardedAt,
    required this.expiresAt,
    required this.createdAt,
    this.qrImageBase64,
    this.scannedByDriverId,
    this.scannedByDriverName,
  });

  bool get isUpcoming => status == 'pending' || status == 'confirmed';
  bool get isCompleted => status == 'boarded';
  bool get isCancelled => status == 'cancelled';

  String get shortRef => id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();

  factory ClientBooking.fromJson(Map<String, dynamic> json) {
    final seatsList = (json['seats'] as List<dynamic>? ?? [])
        .map((s) => BookingSeatDetail.fromJson(s as Map<String, dynamic>))
        .toList();

    return ClientBooking(
      id: json['id'] as String,
      tripId: json['trip_id'] as String? ?? '',
      seats: seatsList,
      status: json['status'] as String? ?? 'pending',
      totalFare: double.tryParse(json['total_fare']?.toString() ?? '0') ?? 0.0,
      discountAmount: double.tryParse(json['discount_amount']?.toString() ?? '0') ?? 0.0,
      familyPackage: json['family_package'] as bool? ?? false,
      holdDurationMinutes: json['hold_duration_minutes'] as int? ?? 0,
      boardedAt: json['boarded_at'] != null
          ? DateTime.tryParse(json['boarded_at'] as String)
          : null,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      qrImageBase64: json['qr_image_base64'] as String?,
      scannedByDriverId: json['scanned_by_driver_id'] as String?,
      scannedByDriverName: json['scanned_by_driver_name'] as String?,
    );
  }
}
