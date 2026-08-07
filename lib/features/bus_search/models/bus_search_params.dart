class BusSearchParams {
  // Empty from/to means "all trips" (e.g. an offer that applies to every trip).
  final String from;
  final String to;
  final DateTime date;
  final int passengers;
  final String? offerId;
  final double? offerDiscountPercent;
  final String? offerTitle;
  // When set, results are filtered to this specific trip only.
  final String? tripId;

  const BusSearchParams({
    required this.from,
    required this.to,
    required this.date,
    this.passengers = 1,
    this.offerId,
    this.offerDiscountPercent,
    this.offerTitle,
    this.tripId,
  });

  bool get isAllTrips => from.isEmpty || to.isEmpty;

  BusSearchParams copyWith({String? from, String? to, DateTime? date}) {
    return BusSearchParams(
      from: from ?? this.from,
      to: to ?? this.to,
      date: date ?? this.date,
      passengers: passengers,
      offerId: offerId,
      offerDiscountPercent: offerDiscountPercent,
      offerTitle: offerTitle,
      tripId: tripId,
    );
  }
}
