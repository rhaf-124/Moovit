class TripSeatResponse {
  final String id;
  final String seatNumber;
  final String status;
  final DateTime? reservedUntil;

  TripSeatResponse({
    required this.id,
    required this.seatNumber,
    required this.status,
    this.reservedUntil,
  });

  factory TripSeatResponse.fromJson(Map<String, dynamic> json) {
    return TripSeatResponse(
      id: json['id'] as String,
      seatNumber: json['seat_number'] as String,
      status: json['status'] as String,
      reservedUntil: json['reserved_until'] != null
          ? DateTime.tryParse(json['reserved_until'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'seat_number': seatNumber,
      'status': status,
      'reserved_until': reservedUntil?.toIso8601String(),
    };
  }

  /// True if this seat is currently unavailable (reserved and hold not expired).
  bool get isEffectivelyUnavailable {
    if (status == 'booked') return true;
    if (status == 'reserved') {
      if (reservedUntil == null) return true;
      return reservedUntil!.isAfter(DateTime.now().toUtc());
    }
    return false;
  }
}

