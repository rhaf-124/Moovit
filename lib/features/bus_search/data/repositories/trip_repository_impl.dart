import '../../domain/repositories/trip_repository.dart';
import '../../models/popular_route_model.dart';
import '../../models/special_offer_model.dart';
import '../../models/trip_live_location.dart';
import '../../models/trip_response.dart';
import '../../models/trip_seat_response.dart';
import '../datasources/trip_remote_datasource.dart';

class TripRepositoryImpl implements TripRepository {
  const TripRepositoryImpl(this._remoteDataSource);

  final TripRemoteDataSource _remoteDataSource;

  @override
  Future<List<SpecialOfferModel>> getSpecialOffers() =>
      _remoteDataSource.getSpecialOffers();

  @override
  Future<List<PopularRouteModel>> getPopularRoutes() =>
      _remoteDataSource.getPopularRoutes();

  @override
  Future<List<TripResponse>> searchTrips({
    String? origin,
    String? destination,
    String? date,
    int? page,
    int? limit,
  }) {
    return _remoteDataSource.searchTrips(
      origin: origin,
      destination: destination,
      date: date,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<TripResponse> getTrip(String tripId) {
    return _remoteDataSource.getTrip(tripId);
  }

  @override
  Future<List<TripSeatResponse>> getTripSeats(String tripId) {
    return _remoteDataSource.getTripSeats(tripId);
  }

  @override
  Future<TripLiveLocation> getTripLiveLocation(String tripId) =>
      _remoteDataSource.getTripLiveLocation(tripId);
}
