import '../../../../core/constants/api_constants.dart';

class AssignedBusModel {
  final String id;
  final String plateNumber;
  final int capacity;
  final String model;
  final String? imageUrl; // raw URL as returned by the API

  const AssignedBusModel({
    required this.id,
    required this.plateNumber,
    required this.capacity,
    required this.model,
    this.imageUrl,
  });

  factory AssignedBusModel.fromJson(Map<String, dynamic> json) {
    final rawImage = (json['image_url'] ?? json['bus_image']) as String?;
    return AssignedBusModel(
      id: json['id'] as String? ?? '',
      plateNumber: json['plate_number'] as String? ?? '',
      capacity: json['capacity'] as int? ?? 0,
      model: json['model'] as String? ?? '',
      imageUrl: _fixUrl(rawImage),
    );
  }
}

class DriverProfileModel {
  final String driverId;
  final String userId;
  final String fullName;
  final String phone;
  final String email;
  final String licenseNumber;
  final String licenseExpiry;
  final bool isAvailable;
  final String? profileImageUrl; // raw URL as returned by the API
  final AssignedBusModel? assignedBus;

  const DriverProfileModel({
    required this.driverId,
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.licenseNumber,
    required this.licenseExpiry,
    required this.isAvailable,
    this.profileImageUrl,
    this.assignedBus,
  });

  factory DriverProfileModel.fromJson(Map<String, dynamic> json) {
    return DriverProfileModel(
      driverId: json['driver_id'] as String,
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      licenseNumber: json['license_number'] as String? ?? '',
      licenseExpiry: json['license_expiry'] as String? ?? '',
      isAvailable: json['is_available'] as bool? ?? false,
      profileImageUrl: _fixUrl(json['profile_image_url'] as String?),
      assignedBus: json['assigned_bus'] != null
          ? AssignedBusModel.fromJson(
              json['assigned_bus'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Replaces 127.0.0.1 / localhost in server-returned URLs with the actual
/// server host so the app can reach media files when running on a device.
String? _fixUrl(String? raw) {
  if (raw == null) return null;
  try {
    final serverUri = Uri.parse(ApiConstants.baseUrl);
    final rawUri = Uri.parse(raw);
    final isLocalhost =
        rawUri.host == '127.0.0.1' || rawUri.host == 'localhost';
    if (isLocalhost) {
      return rawUri
          .replace(host: serverUri.host, port: serverUri.port)
          .toString();
    }
  } catch (_) {}
  return raw;
}
