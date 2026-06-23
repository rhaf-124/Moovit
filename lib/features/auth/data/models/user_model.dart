class UserModel {
  final String id;
  final String email;
  final String phone;
  final String fullName;
  final String role;
  final bool isActive;
  final bool isVerified;
  final String? profileImageUrl;

  const UserModel({
    required this.id,
    required this.email,
    required this.phone,
    required this.fullName,
    required this.role,
    required this.isActive,
    required this.isVerified,
    this.profileImageUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String,
        fullName: json['full_name'] as String,
        role: json['role'] as String,
        isActive: json['is_active'] as bool,
        isVerified: json['is_verified'] as bool,
        profileImageUrl: json['profile_image_url'] as String?,
      );
}
