class ScanResultModel {
  final String passengerName;
  final String seatNumber;
  final String tripId;
  final String tripStatus;
  final String bookingStatus;
  final bool isPaid;
  final DateTime? boardedAt;

  const ScanResultModel({
    required this.passengerName,
    required this.seatNumber,
    required this.tripId,
    required this.tripStatus,
    required this.bookingStatus,
    required this.isPaid,
    this.boardedAt,
  });

  factory ScanResultModel.fromJson(Map<String, dynamic> json) {
    return ScanResultModel(
      passengerName: json['passenger_name'] as String? ?? 'Unknown',
      seatNumber: json['seat_number'] as String? ?? '',
      tripId: json['trip_id'] as String? ?? '',
      tripStatus: json['trip_status'] as String? ?? '',
      bookingStatus: json['booking_status'] as String? ?? 'boarded',
      isPaid: json['is_paid'] as bool? ?? true,
      boardedAt: json['boarded_at'] != null
          ? DateTime.tryParse(json['boarded_at'] as String)
          : null,
    );
  }
}
