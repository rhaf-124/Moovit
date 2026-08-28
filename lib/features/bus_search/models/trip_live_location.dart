class TripLiveLocation {
  final String tripId;
  final String status;
  final double? currentLatitude;
  final double? currentLongitude;

  /// When the driver last reported [currentLatitude]/[currentLongitude].
  /// Null means they have never reported.
  final DateTime? locationUpdatedAt;
  final String origin;
  final String destination;
  final DateTime departureTime;
  final String busModel;
  final String busPlate;

  const TripLiveLocation({
    required this.tripId,
    required this.status,
    this.currentLatitude,
    this.currentLongitude,
    this.locationUpdatedAt,
    required this.origin,
    required this.destination,
    required this.departureTime,
    required this.busModel,
    required this.busPlate,
  });

  bool get hasLocation =>
      currentLatitude != null &&
      currentLongitude != null &&
      (currentLatitude! != 0.0 || currentLongitude! != 0.0);

  /// A position older than this is a last-known location, not a live one.
  /// Drivers push every 10s while moving, so a longer gap means their app was
  /// killed, or the phone lost signal or power.
  static const staleAfter = Duration(seconds: 60);

  /// How long ago the driver reported, or null if they never have.
  Duration? get locationAge => locationUpdatedAt == null
      ? null
      : DateTime.now().difference(locationUpdatedAt!);

  /// The bus was here, but is no longer confirming it still is.
  ///
  /// Distinct from [hasLocation]: the map still knows where the bus was. Drawing
  /// a stale position identically to a live one made a driver's dead phone look
  /// like a moving bus.
  bool get isLocationStale {
    if (!hasLocation) return false;
    final age = locationAge;
    return age == null || age > staleAfter;
  }

  /// Compact "2m ago" label for the last report.
  String get locationAgeLabel {
    final age = locationAge;
    if (age == null) return 'never reported';
    if (age.inSeconds < 10) return 'just now';
    if (age.inSeconds < 60) return '${age.inSeconds}s ago';
    if (age.inMinutes < 60) return '${age.inMinutes}m ago';
    if (age.inHours < 24) return '${age.inHours}h ago';
    return '${age.inDays}d ago';
  }

  factory TripLiveLocation.fromJson(Map<String, dynamic> json) {
    return TripLiveLocation(
      tripId: json['trip_id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      currentLatitude: json['current_latitude'] != null
          ? double.tryParse(json['current_latitude'].toString())
          : null,
      currentLongitude: json['current_longitude'] != null
          ? double.tryParse(json['current_longitude'].toString())
          : null,
      locationUpdatedAt: json['location_updated_at'] != null
          ? DateTime.tryParse(json['location_updated_at'].toString())?.toLocal()
          : null,
      origin: json['route_origin'] as String? ?? '',
      destination: json['route_destination'] as String? ?? '',
      departureTime: json['departure_time'] != null
          ? DateTime.parse(json['departure_time'] as String)
          : DateTime.now(),
      busModel: json['bus_model'] as String? ?? '',
      busPlate: json['bus_plate'] as String? ?? '',
    );
  }
}
