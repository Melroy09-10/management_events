import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum UserRole { superAdmin, admin, user }

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.user:
        return 'User';
    }
  }

  String get description {
    switch (this) {
      case UserRole.superAdmin:
        return 'Full control over the platform & members';
      case UserRole.admin:
        return 'Manage events & members';
      case UserRole.user:
        return 'Standard access to the app';
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.superAdmin:
        return Icons.shield_moon_rounded;
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
      case UserRole.user:
        return Icons.person_rounded;
    }
  }

  Color get color {
    switch (this) {
      case UserRole.superAdmin:
        return AppColors.superAdmin;
      case UserRole.admin:
        return AppColors.admin;
      case UserRole.user:
        return AppColors.user;
    }
  }

  String get storageValue => name;

  /// Legacy accounts written before the "member" → "user" role rename still
  /// have the old literal string stored in Firestore; since no enum value's
  /// `name` matches "member" anymore, they fall through to this default —
  /// which is exactly the normal-user role they always meant. No live data
  /// migration is required for the app to keep working correctly.
  static UserRole fromStorage(String value) {
    return UserRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => UserRole.user,
    );
  }
}
