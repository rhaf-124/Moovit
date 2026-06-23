import 'package:dio/dio.dart';
import '../../models/driver_profile_model.dart';
import '../../models/driver_report_model.dart';
import '../../models/driver_trip_model.dart';
import '../../models/scan_result_model.dart';

class DriverRemoteDataSource {
  const DriverRemoteDataSource(this._dio);

  final Dio _dio;

  Future<DriverProfileModel> getDriverProfile() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/driver/profile');
    return DriverProfileModel.fromJson(response.data!);
  }

  Future<List<DriverTripModel>> getDriverTrips() async {
    final response = await _dio.get<List<dynamic>>('/driver/trips');
    return response.data!
        .map((json) => DriverTripModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<DriverTripModel> updateTripStatus({
    required String tripId,
    required String status,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/driver/trips/$tripId/status',
      data: {'status': status},
    );
    return DriverTripModel.fromJson(response.data!);
  }

  Future<void> updateTripLocation({
    required String tripId,
    required double latitude,
    required double longitude,
  }) async {
    await _dio.patch<void>(
      '/driver/trips/$tripId/location',
      data: {
        'current_latitude': latitude,
        'current_longitude': longitude,
      },
    );
  }

  Future<ScanResultModel> scanTicket({required String code}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/driver/scan',
      data: {'qr_token': code},
    );
    return ScanResultModel.fromJson(response.data!);
  }

  Future<DriverReportModel> submitReport({
    required String category,
    required String subject,
    required String description,
    String? tripId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/driver/reports',
      data: {
        'category': category,
        'subject': subject,
        'description': description,
        'trip_id': tripId,
      }..removeWhere((_, v) => v == null),
    );
    return DriverReportModel.fromJson(response.data!);
  }

  Future<List<DriverReportModel>> listReports() async {
    final response = await _dio.get<List<dynamic>>('/driver/reports');
    return (response.data ?? [])
        .map((e) => DriverReportModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DriverProfileModel> uploadProfilePicture(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/driver/profile-picture',
      data: formData,
    );
    return DriverProfileModel.fromJson(response.data!);
  }
}
