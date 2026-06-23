import 'package:dio/dio.dart';

import '../../models/popular_route_model.dart';
import '../../models/special_offer_model.dart';
import '../../models/trip_live_location.dart';
import '../../models/trip_response.dart';
import '../../models/trip_seat_response.dart';

class TripRemoteDataSource {
  const TripRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<TripResponse>> searchTrips({
    String? origin,
    String? destination,
    String? date,
    int? page,
    int? limit,
  }) async {
    final Map<String, dynamic> queryParameters = {};
    if (origin != null && origin.isNotEmpty) {
      queryParameters['origin'] = origin;
    }
    if (destination != null && destination.isNotEmpty) {
      queryParameters['destination'] = destination;
    }
    if (date != null && date.isNotEmpty) {
      queryParameters['date'] = date;
    }
    if (page != null) {
      queryParameters['page'] = page;
    }
    if (limit != null) {
      queryParameters['limit'] = limit;
    }

    final response = await _dio.get<List<dynamic>>(
      '/trips/',
      queryParameters: queryParameters,
    );

    return response.data!
        .map((e) => TripResponse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SpecialOfferModel>> getSpecialOffers() async {
    final response = await _dio.get<List<dynamic>>('/offers/');
    return (response.data ?? [])
        .map((e) => SpecialOfferModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<PopularRouteModel>> getPopularRoutes() async {
    final response = await _dio.get<List<dynamic>>('/trips/popular-routes');
    return (response.data ?? [])
        .map((e) => PopularRouteModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TripResponse> getTrip(String tripId) async {
    final response = await _dio.get<Map<String, dynamic>>('/trips/$tripId');
    return TripResponse.fromJson(response.data!);
  }

  Future<List<TripSeatResponse>> getTripSeats(String tripId) async {
    final response = await _dio.get<List<dynamic>>('/trips/$tripId/seats');
    return response.data!
        .map((e) => TripSeatResponse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TripLiveLocation> getTripLiveLocation(String tripId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/trips/$tripId/live-location',
    );
    return TripLiveLocation.fromJson(response.data!);
  }
}
