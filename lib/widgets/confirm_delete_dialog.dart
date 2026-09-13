import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The single confirmation dialog used before any delete action in the app.
Future<bool> confirmDelete(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete'),
      content: const Text('Are you sure you want to delete this?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text('Delete', style: TextStyle(color: AppColors.danger)),
        ),
      ],
    ),
  );
  return confirmed == true;
}
