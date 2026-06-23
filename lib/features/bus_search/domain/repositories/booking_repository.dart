import '../../models/booking_response.dart';
import '../../models/client_booking.dart';
import '../../models/confirmed_booking_response.dart';
import '../../models/payment_response.dart';

abstract interface class BookingRepository {
  Future<List<ClientBooking>> listBookings();

  Future<BookingResponse> createBooking({
    required String tripId,
    required List<Map<String, dynamic>> seats,
    bool familyPackage,
    String? offerId,
  });

  Future<PaymentResponse> initiatePayment({
    required String bookingId,
    required String method,
  });

  Future<PaymentResponse> verifyPayment(String transactionRef);

  Future<ConfirmedBookingResponse> getBooking(String bookingId);

  Future<ClientBooking> getBookingDetails(String bookingId);
}
