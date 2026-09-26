import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../utils/text_formatters.dart';
import '../widgets/app_text_field.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/contact_import.dart';
import '../widgets/primary_button.dart';

/// Admin/Super Admin only: the signed-in Admin's own roster of Members —
/// name & phone number only, no Firebase Auth login of their own. Used to
/// quickly build up who's available for event allocation, either one at a
/// time or in bulk from the phone's contacts.
class MembersScreen extends StatelessWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = context.read<DataService>();

    // --- TEMPORARY DEBUG LOGGING for the Members permission-denied issue.
    // Remove this block once the underlying Firestore rules problem is
    // confirmed fixed. Prints once per build of this screen.
    final debugUid = FirebaseAuth.instance.currentUser?.uid;
    final debugRole = context.read<AuthService>().currentUser?.role;
    debugPrint(
      '[MembersDebug] FirebaseAuth.instance.currentUser?.uid = $debugUid',
    );
    debugPrint('[MembersDebug] user document path = users/$debugUid');
    debugPrint(
      '[MembersDebug] role read from that document (live, via AuthService) = '
      '${debugRole?.storageValue}',
    );
    debugPrint(
      '[MembersDebug] Members query path = users/$debugUid/members '
      '(orderBy: name)',
    );
    // --- end temporary debug logging ---

    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMemberSheet(context),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Member'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Member>>(
          stream: dataService.members(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              // --- TEMPORARY DEBUG LOGGING ---
              final error = snapshot.error;
              if (error is FirebaseException) {
                debugPrint(
                  '[MembersDebug] Firestore error — code: ${error.code}, '
                  'message: ${error.message}, plugin: ${error.plugin}',
                );
              } else {
                debugPrint('[MembersDebug] Non-Firestore error: $error');
              }
              // --- end temporary debug logging ---
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load members:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
              );
            }

            final members = snapshot.data ?? const [];
            if (members.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.groups_outlined,
                        size: 56,
                        color: AppColors.textSecondaryLight,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No members added yet',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add one manually or import several from your contacts.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondaryLight),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: members.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _MemberTile(member: members[index]),
            );
          },
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final Member member;
  const _MemberTile({required this.member});

  @override
  Widget build(BuildContext context) {
    final accent = onSurfaceAccent(context, AppColors.gold);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12.withValues(alpha: 0.06)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.12),
          child: Icon(Icons.person_rounded, color: accent),
        ),
        title: Text(
          member.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(member.phone),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              color: AppColors.textSecondaryLight,
              onPressed: () => _showMemberForm(context, existing: member),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              color: AppColors.danger,
              onPressed: () => _confirmDelete(context, member),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Member member) async {
    final confirmed = await confirmDelete(context);
    if (!confirmed || !context.mounted) return;

    try {
      await context.read<DataService>().deleteMemberEntry(member.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }
}

// --- Add Member: manual entry vs. import from contacts ---

void _showAddMemberSheet(BuildContext context) {
  showAddChoiceSheet(
    context,
    title: 'Add Member',
    onManual: () => _showMemberForm(context),
    onImport: () => _startContactImport(context),
  );
}

Future<void> _startContactImport(BuildContext context) {
  final dataService = context.read<DataService>();
  return startContactImport(
    context,
    labels: const ContactImportLabels('Member', 'Members'),
    loadExisting: () async => [
      for (final m in await dataService.membersOnce())
        (id: m.id, name: m.name, phone: m.phone),
    ],
    save: ({required added, required updated}) =>
        dataService.importMembers(newMembers: added, updatedMembers: updated),
  );
}

// --- Add Manually ---

Future<void> _showMemberForm(BuildContext context, {Member? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MemberFormSheet(existing: existing),
  );
}

class _MemberFormSheet extends StatefulWidget {
  final Member? existing;
  const _MemberFormSheet({this.existing});

  @override
  State<_MemberFormSheet> createState() => _MemberFormSheetState();
}

class _MemberFormSheetState extends State<_MemberFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _phoneController = TextEditingController(
      text: widget.existing?.phone ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final dataService = context.read<DataService>();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    try {
      if (widget.existing == null) {
        await dataService.addMemberEntry(name: name, phone: phone);
      } else {
        await dataService.updateMemberEntry(
          widget.existing!.id,
          name: name,
          phone: phone,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                isEditing ? 'Edit Member' : 'Add Member',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 20),
              AppTextField(
                controller: _nameController,
                label: 'Name *',
                icon: Icons.person_outline_rounded,
                inputFormatters: [FirstLetterCapitalizeFormatter()],
                validator: (value) {
                  if (value == null || value.trim().isEmpty)
                    return 'Name is required';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _phoneController,
                label: 'Phone number *',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 10,
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return 'Phone number is required';
                  if (trimmed.length != 10)
                    return 'Enter a valid 10-digit phone number';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: isEditing ? 'Update' : 'Save',
                onPressed: _save,
                loading: _saving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
