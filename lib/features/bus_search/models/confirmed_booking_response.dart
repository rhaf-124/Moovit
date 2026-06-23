class ConfirmedBookingResponse {
  final String id;
  final String clientId;
  final String tripId;
  final String status;
  final double totalFare;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final String? qrImageBase64;

  const ConfirmedBookingResponse({
    required this.id,
    required this.clientId,
    required this.tripId,
    required this.status,
    required this.totalFare,
    this.expiresAt,
    required this.createdAt,
    this.qrImageBase64,
  });

  factory ConfirmedBookingResponse.fromJson(Map<String, dynamic> json) {
    return ConfirmedBookingResponse(
      id: json['id'] as String,
      clientId: json['client_id'] as String? ?? '',
      tripId: json['trip_id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      totalFare: double.tryParse(json['total_fare']?.toString() ?? '0') ?? 0.0,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      qrImageBase64: json['qr_image_base64'] as String?,
    );
  }
}
