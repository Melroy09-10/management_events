import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/admin_request.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Lets the Super Admin review pending "make me an Admin" requests from
/// users and approve or reject each one.
class AdminRequestsScreen extends StatelessWidget {
  const AdminRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Requests')),
      body: SafeArea(
        child: StreamBuilder<List<AdminRequest>>(
          stream: auth.pendingAdminRequests(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load requests:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
              );
            }
            final requests = snapshot.data ?? const [];
            if (requests.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_rounded, size: 56, color: AppColors.textSecondaryLight),
                      const SizedBox(height: 12),
                      Text(
                        'No pending requests',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _RequestCard(request: requests[index]),
            );
          },
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final AdminRequest request;
  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.admin.withValues(alpha: 0.15),
                child: Icon(Icons.admin_panel_settings_rounded, color: AppColors.admin),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      request.email,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await auth.rejectAdminRequest(request.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Rejected ${request.name}\'s request')),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    await auth.approveAdminRequest(request);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${request.name} is now an Admin')),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(backgroundColor: AppColors.admin),
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
