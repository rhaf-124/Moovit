import '../../models/complaint_model.dart';
import '../../models/rating_model.dart';

abstract interface class ReviewRepository {
  Future<ComplaintModel> submitComplaint({
    required String tripId,
    required String subject,
    required String description,
  });
  Future<List<ComplaintModel>> listComplaints({String? tripId});
  Future<RatingModel> submitRating({
    required String tripId,
    required int tripRating,
    required int driverRating,
    String? comment,
  });
  Future<List<RatingModel>> listRatings({String? tripId});
}
