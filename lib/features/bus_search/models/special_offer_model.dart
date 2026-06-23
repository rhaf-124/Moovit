class SpecialOfferModel {
  final String id;
  final String title;
  final String description;
  final String badgeText;
  final double discountPercent;
  final DateTime validFrom;
  final DateTime validUntil;
  final bool isActive;
  final int? maxUses;
  final int currentUses;
  final String? tripId;
  final String? routeId;
  final String colorHexStart;
  final String colorHexEnd;
  final String iconName;
  final String? routeOrigin;
  final String? routeDestination;

  const SpecialOfferModel({
    required this.id,
    required this.title,
    required this.description,
    required this.badgeText,
    required this.discountPercent,
    required this.validFrom,
    required this.validUntil,
    required this.isActive,
    this.maxUses,
    required this.currentUses,
    this.tripId,
    this.routeId,
    required this.colorHexStart,
    required this.colorHexEnd,
    required this.iconName,
    this.routeOrigin,
    this.routeDestination,
  });

  factory SpecialOfferModel.fromJson(Map<String, dynamic> json) {
    return SpecialOfferModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      badgeText: json['badge_text'] as String,
      discountPercent: (json['discount_percent'] as num).toDouble(),
      validFrom: DateTime.parse(json['valid_from'] as String),
      validUntil: DateTime.parse(json['valid_until'] as String),
      isActive: json['is_active'] as bool,
      maxUses: json['max_uses'] as int?,
      currentUses: json['current_uses'] as int? ?? 0,
      tripId: json['trip_id'] as String?,
      routeId: json['route_id'] as String?,
      colorHexStart: json['color_hex_start'] as String? ?? '#6366F1',
      colorHexEnd: json['color_hex_end'] as String? ?? '#14B8A6',
      iconName: json['icon_name'] as String? ?? 'local_offer',
      routeOrigin: json['route_origin'] as String?,
      routeDestination: json['route_destination'] as String?,
    );
  }
}
