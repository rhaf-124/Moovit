import '../../models/driver_profile_model.dart';
import '../../models/driver_report_model.dart';
import '../../models/driver_trip_model.dart';
import '../../models/scan_result_model.dart';

abstract class DriverRepository {
  Future<DriverProfileModel> getDriverProfile();
  Future<List<DriverTripModel>> getDriverTrips();
  Future<DriverTripModel> updateTripStatus({
    required String tripId,
    required String status,
  });
  Future<void> updateTripLocation({
    required String tripId,
    required double latitude,
    required double longitude,
  });
  Future<ScanResultModel> scanTicket({required String code});
  Future<DriverReportModel> submitReport({
    required String category,
    required String subject,
    required String description,
    String? tripId,
  });
  Future<List<DriverReportModel>> listReports();
  Future<DriverProfileModel> uploadProfilePicture(String filePath);
}
