import 'package:cloud_firestore/cloud_firestore.dart';

enum AdminRequestStatus { pending, approved, rejected }

extension AdminRequestStatusX on AdminRequestStatus {
  String get storageValue => name;

  static AdminRequestStatus fromStorage(String value) {
    return AdminRequestStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => AdminRequestStatus.pending,
    );
  }
}

/// A member's request to be promoted to Admin, reviewed by the Super Admin.
class AdminRequest {
  final String id;
  final String userId;
  final String name;
  final String email;
  final AdminRequestStatus status;
  final DateTime? requestedAt;

  const AdminRequest({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.status,
    required this.requestedAt,
  });

  factory AdminRequest.fromJson(String id, Map<String, dynamic> json) => AdminRequest(
        id: id,
        userId: json['userId'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        status: AdminRequestStatusX.fromStorage(json['status'] as String),
        requestedAt: (json['requestedAt'] as Timestamp?)?.toDate(),
      );
}
