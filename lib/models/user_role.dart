import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum UserRole { superAdmin, admin, member }

extension UserRoleX on UserRole {
  String get label {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.member:
        return 'Member';
    }
  }

  String get description {
    switch (this) {
      case UserRole.superAdmin:
        return 'Full control over the platform & members';
      case UserRole.admin:
        return 'Manage events & members';
      case UserRole.member:
        return 'Standard access to the app';
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.superAdmin:
        return Icons.shield_moon_rounded;
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
      case UserRole.member:
        return Icons.person_rounded;
    }
  }

  Color get color {
    switch (this) {
      case UserRole.superAdmin:
        return AppColors.superAdmin;
      case UserRole.admin:
        return AppColors.admin;
      case UserRole.member:
        return AppColors.member;
    }
  }

  String get storageValue => name;

  static UserRole fromStorage(String value) {
    return UserRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => UserRole.member,
    );
  }
}
