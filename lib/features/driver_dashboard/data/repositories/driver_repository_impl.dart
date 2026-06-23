import '../../domain/repositories/driver_repository.dart';
import '../../models/driver_profile_model.dart';
import '../../models/driver_report_model.dart';
import '../../models/driver_trip_model.dart';
import '../../models/scan_result_model.dart';
import '../datasources/driver_remote_datasource.dart';

class DriverRepositoryImpl implements DriverRepository {
  const DriverRepositoryImpl(this._dataSource);

  final DriverRemoteDataSource _dataSource;

  @override
  Future<DriverProfileModel> getDriverProfile() =>
      _dataSource.getDriverProfile();

  @override
  Future<List<DriverTripModel>> getDriverTrips() =>
      _dataSource.getDriverTrips();

  @override
  Future<DriverTripModel> updateTripStatus({
    required String tripId,
    required String status,
  }) =>
      _dataSource.updateTripStatus(tripId: tripId, status: status);

  @override
  Future<void> updateTripLocation({
    required String tripId,
    required double latitude,
    required double longitude,
  }) =>
      _dataSource.updateTripLocation(
        tripId: tripId,
        latitude: latitude,
        longitude: longitude,
      );

  @override
  Future<ScanResultModel> scanTicket({required String code}) =>
      _dataSource.scanTicket(code: code);

  @override
  Future<DriverReportModel> submitReport({
    required String category,
    required String subject,
    required String description,
    String? tripId,
  }) =>
      _dataSource.submitReport(
        category: category,
        subject: subject,
        description: description,
        tripId: tripId,
      );

  @override
  Future<List<DriverReportModel>> listReports() => _dataSource.listReports();

  @override
  Future<DriverProfileModel> uploadProfilePicture(String filePath) =>
      _dataSource.uploadProfilePicture(filePath);
}
