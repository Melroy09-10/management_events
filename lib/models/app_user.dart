import 'user_role.dart';

class AppUser {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String place;
  final UserRole role;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.place,
    required this.role,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'phone': phone,
        'place': place,
        'role': role.storageValue,
      };

  factory AppUser.fromJson(String id, Map<String, dynamic> json) => AppUser(
        id: id,
        name: json['name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String? ?? '',
        place: json['place'] as String? ?? '',
        role: UserRoleX.fromStorage(json['role'] as String),
      );
}
