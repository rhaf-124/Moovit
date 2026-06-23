class BookingResponse {
  final String id;
  final String clientId;
  final String tripId;
  final String status;
  final double totalFare;
  final double discountAmount;
  final int holdDurationMinutes;
  final DateTime expiresAt;
  final DateTime createdAt;

  const BookingResponse({
    required this.id,
    required this.clientId,
    required this.tripId,
    required this.status,
    required this.totalFare,
    this.discountAmount = 0.0,
    required this.holdDurationMinutes,
    required this.expiresAt,
    required this.createdAt,
  });

  factory BookingResponse.fromJson(Map<String, dynamic> json) {
    return BookingResponse(
      id: json['id'] as String,
      clientId: json['client_id'] as String? ?? '',
      tripId: json['trip_id'] as String,
      status: json['status'] as String,
      totalFare: double.tryParse(json['total_fare']?.toString() ?? '0') ?? 0.0,
      discountAmount: double.tryParse(json['discount_amount']?.toString() ?? '0') ?? 0.0,
      holdDurationMinutes: json['hold_duration_minutes'] as int? ?? 30,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
