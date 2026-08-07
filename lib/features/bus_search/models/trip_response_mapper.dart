import 'bus_model.dart';
import 'trip_response.dart';
import 'trip_seat_response.dart';

extension TripResponseX on TripResponse {
  BusModel toBusModel({List<TripSeatResponse> seats = const []}) {
    // Calculate duration (arrivalTime may be null for scheduled trips)
    final effectiveArrival = arrivalTime ?? departureTime;
    final diff = effectiveArrival.difference(departureTime);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    final durationStr = arrivalTime != null ? '${hours}h ${minutes}m' : 'TBD';

    // Format departure and arrival times to HH:mm
    String formatTime(DateTime dt) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    // Convert seat responses to SeatInfo
    final prePopulated = seats
        .where((s) => s.status != 'available')
        .map((s) {
          final number = int.tryParse(s.seatNumber) ?? 0;
          final seatStatus = s.status == 'reserved' ? SeatStatus.reserved : SeatStatus.booked;
          return SeatInfo(
            number: number,
            status: seatStatus,
            gender: null, // gender is not returned by the API
          );
        })
        .where((s) => s.number > 0)
        .toList();

    // If seats list is empty, default totalSeats to 48. Otherwise, use seats list length.
    final total = seats.isEmpty ? 48 : seats.length;

    return BusModel(
      id: id,
      name: busModel,
      busNumber: busPlate,
      rating: 4.5, // default rating
      departureTime: formatTime(departureTime),
      arrivalTime: arrivalTime != null ? formatTime(arrivalTime!) : '--:--',
      duration: durationStr,
      distanceKm: 240, // default distance
      pricePerSeat: fare,
      totalSeats: total,
      amenities: const ['wifi', 'ac', 'charging'], // default amenities
      tags: const ['Express'], // default tags
      prePopulatedSeats: prePopulated,
      imageUrl: busImage,
      origin: origin,
      destination: destination,
    );
  }
}
