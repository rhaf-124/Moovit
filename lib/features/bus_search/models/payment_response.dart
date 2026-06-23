class PaymentResponse {
  final String id;
  final String bookingId;
  final double amount;
  final String method;
  final String status;
  final String transactionRef;
  final String? checkoutUrl;

  const PaymentResponse({
    required this.id,
    required this.bookingId,
    required this.amount,
    required this.method,
    required this.status,
    required this.transactionRef,
    this.checkoutUrl,
  });

  factory PaymentResponse.fromJson(Map<String, dynamic> json) {
    return PaymentResponse(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      method: json['method'] as String? ?? '',
      status: json['status'] as String? ?? '',
      transactionRef: json['transaction_ref'] as String? ?? '',
      checkoutUrl: json['checkout_url'] as String?,
    );
  }
}
