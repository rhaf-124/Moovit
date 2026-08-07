import '../../domain/repositories/review_repository.dart';
import '../../models/complaint_model.dart';
import '../../models/rating_model.dart';
import '../datasources/review_remote_datasource.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  const ReviewRepositoryImpl(this._dataSource);
  final ReviewRemoteDataSource _dataSource;

  @override
  Future<ComplaintModel> submitComplaint({
    required String tripId,
    required String subject,
    required String description,
  }) => _dataSource.submitComplaint(tripId: tripId, subject: subject, description: description);

  @override
  Future<List<ComplaintModel>> listComplaints({String? tripId}) =>
      _dataSource.listComplaints(tripId: tripId);

  @override
  Future<RatingModel> submitRating({
    required String tripId,
    required int tripRating,
    required int driverRating,
    String? comment,
  }) => _dataSource.submitRating(
    tripId: tripId,
    tripRating: tripRating,
    driverRating: driverRating,
    comment: comment,
  );

  @override
  Future<List<RatingModel>> listRatings({String? tripId}) =>
      _dataSource.listRatings(tripId: tripId);
}
