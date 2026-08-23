import '../../domain/repositories/booking_repository.dart';
import '../../models/booking_response.dart';
import '../../models/client_booking.dart';
import '../../models/confirmed_booking_response.dart';
import '../../models/payment_response.dart';
import '../datasources/booking_remote_datasource.dart';

class BookingRepositoryImpl implements BookingRepository {
  const BookingRepositoryImpl(this._dataSource);

  final BookingRemoteDataSource _dataSource;

  @override
  Future<List<ClientBooking>> listBookings() => _dataSource.listBookings();

  @override
  Future<BookingResponse> createBooking({
    required String tripId,
    required List<Map<String, dynamic>> seats,
    bool familyPackage = false,
    String? offerId,
  }) =>
      _dataSource.createBooking(
        tripId: tripId,
        seats: seats,
        familyPackage: familyPackage,
        offerId: offerId,
      );

  @override
  Future<PaymentResponse> initiatePayment({
    required String bookingId,
    required String method,
  }) =>
      _dataSource.initiatePayment(bookingId: bookingId, method: method);

  @override
  Future<PaymentResponse> verifyPayment(String transactionRef) =>
      _dataSource.verifyPayment(transactionRef);

  @override
  Future<PaymentResponse> requestRefund(String transactionRef) =>
      _dataSource.requestRefund(transactionRef);

  @override
  Future<ConfirmedBookingResponse> getBooking(String bookingId) =>
      _dataSource.getBooking(bookingId);

  @override
  Future<ClientBooking> getBookingDetails(String bookingId) =>
      _dataSource.getBookingDetails(bookingId);
}
