import 'booking_response.dart';
import 'bus_model.dart';
import 'confirmed_booking_response.dart';
import 'payment_response.dart';

class SelectedSeat {
  final String seatId; // real UUID from GET /trips/{id}/seats
  final int seatNumber;
  final SeatGender gender;
  final bool hasLuggage;
  final String luggageType; // 'backpack' | 'suitcase' | 'none'

  const SelectedSeat({
    required this.seatId,
    required this.seatNumber,
    required this.gender,
    this.hasLuggage = false,
    this.luggageType = 'none',
  });
}

class BookingData {
  final BusModel bus;
  final String fromCity;
  final String toCity;
  final DateTime date;
  final List<SelectedSeat> selectedSeats;
  final String? offerId;

  // Populated after POST /bookings/
  final BookingResponse? bookingResponse;

  // Populated after POST /payments/
  final PaymentResponse? paymentResponse;

  // Populated after GET /bookings/{id}
  final ConfirmedBookingResponse? confirmedBooking;

  BookingData({
    required this.bus,
    required this.fromCity,
    required this.toCity,
    required this.date,
    required this.selectedSeats,
    this.offerId,
    this.bookingResponse,
    this.paymentResponse,
    this.confirmedBooking,
  });

  String get bookingId =>
      bookingResponse?.id ?? 'BK${DateTime.now().millisecondsSinceEpoch}';

  double get basePrice =>
      bookingResponse?.totalFare ?? selectedSeats.length * bus.pricePerSeat;

  double get taxes => basePrice * 0.18;
  double get total => bookingResponse?.totalFare ?? (basePrice + taxes);

  BookingData copyWith({
    BookingResponse? bookingResponse,
    PaymentResponse? paymentResponse,
    ConfirmedBookingResponse? confirmedBooking,
  }) {
    return BookingData(
      bus: bus,
      fromCity: fromCity,
      toCity: toCity,
      date: date,
      selectedSeats: selectedSeats,
      offerId: offerId,
      bookingResponse: bookingResponse ?? this.bookingResponse,
      paymentResponse: paymentResponse ?? this.paymentResponse,
      confirmedBooking: confirmedBooking ?? this.confirmedBooking,
    );
  }
}

