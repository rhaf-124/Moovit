import '../../models/popular_route_model.dart';
import '../../models/special_offer_model.dart';
import '../../models/trip_live_location.dart';
import '../../models/trip_response.dart';
import '../../models/trip_seat_response.dart';

abstract interface class TripRepository {
  Future<List<SpecialOfferModel>> getSpecialOffers();

  Future<List<PopularRouteModel>> getPopularRoutes();

  Future<List<TripResponse>> searchTrips({
    String? origin,
    String? destination,
    String? date,
    int? page,
    int? limit,
  });

  Future<TripResponse> getTrip(String tripId);

  Future<List<TripSeatResponse>> getTripSeats(String tripId);

  Future<TripLiveLocation> getTripLiveLocation(String tripId);
}
