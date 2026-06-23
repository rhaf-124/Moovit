class BusSearchParams {
  final String from;
  final String to;
  final DateTime date;
  final int passengers;
  final String? offerId;
  final double? offerDiscountPercent;

  const BusSearchParams({
    required this.from,
    required this.to,
    required this.date,
    this.passengers = 1,
    this.offerId,
    this.offerDiscountPercent,
  });
}
