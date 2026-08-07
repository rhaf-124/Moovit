import 'package:dio/dio.dart';
import '../../models/complaint_model.dart';
import '../../models/rating_model.dart';

class ReviewRemoteDataSource {
  const ReviewRemoteDataSource(this._dio);
  final Dio _dio;

  Future<ComplaintModel> submitComplaint({
    required String tripId,
    required String subject,
    required String description,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/reviews/complaints',
      data: {'trip_id': tripId, 'subject': subject, 'description': description},
    );
    return ComplaintModel.fromJson(response.data!);
  }

  Future<List<ComplaintModel>> listComplaints({String? tripId}) async {
    final response = await _dio.get<List<dynamic>>(
      '/reviews/complaints',
      queryParameters: tripId != null ? {'trip_id': tripId} : null,
    );
    return (response.data ?? [])
        .map((e) => ComplaintModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<RatingModel> submitRating({
    required String tripId,
    required int tripRating,
    required int driverRating,
    String? comment,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/reviews/ratings',
      data: {
        'trip_id': tripId,
        'trip_rating': tripRating,
        'driver_rating': driverRating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
    );
    return RatingModel.fromJson(response.data!);
  }

  Future<List<RatingModel>> listRatings({String? tripId}) async {
    final response = await _dio.get<List<dynamic>>(
      '/reviews/ratings',
      queryParameters: tripId != null ? {'trip_id': tripId} : null,
    );
    return (response.data ?? [])
        .map((e) => RatingModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
