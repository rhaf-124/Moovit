import 'package:dio/dio.dart';

import '../../models/booking_response.dart';
import '../../models/client_booking.dart';
import '../../models/confirmed_booking_response.dart';
import '../../models/payment_response.dart';

class BookingRemoteDataSource {
  const BookingRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<ClientBooking>> listBookings() async {
    final response = await _dio.get<List<dynamic>>('/bookings/');
    return (response.data ?? [])
        .map((e) => ClientBooking.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<BookingResponse> createBooking({
    required String tripId,
    required List<Map<String, dynamic>> seats,
    bool familyPackage = false,
    String? offerId,
  }) async {
    final body = <String, dynamic>{
      'trip_id': tripId,
      'seats': seats,
      'family_package': familyPackage,
    };
    if (offerId != null) body['offer_id'] = offerId;
    final response = await _dio.post<Map<String, dynamic>>('/bookings/', data: body);
    return BookingResponse.fromJson(response.data!);
  }

  Future<PaymentResponse> initiatePayment({
    required String bookingId,
    required String method,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/payments/',
      data: {
        'booking_id': bookingId,
        'method': method,
      },
    );
    return PaymentResponse.fromJson(response.data!);
  }

  Future<PaymentResponse> verifyPayment(String transactionRef) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/payments/verify/$transactionRef',
    );
    return PaymentResponse.fromJson(response.data!);
  }

  Future<PaymentResponse> requestRefund(String transactionRef) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/payments/refund/$transactionRef',
    );
    return PaymentResponse.fromJson(response.data!);
  }

  Future<ConfirmedBookingResponse> getBooking(String bookingId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/bookings/$bookingId',
    );
    return ConfirmedBookingResponse.fromJson(response.data!);
  }

  Future<ClientBooking> getBookingDetails(String bookingId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/bookings/$bookingId',
    );
    return ClientBooking.fromJson(response.data!);
  }
}
