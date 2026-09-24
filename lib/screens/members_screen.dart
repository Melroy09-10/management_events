import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../utils/text_formatters.dart';
import '../widgets/app_text_field.dart';
import '../widgets/confirm_delete_dialog.dart';
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
    debugPrint('[MembersDebug] FirebaseAuth.instance.currentUser?.uid = $debugUid');
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
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _AddMemberChoiceSheet(
      onManual: () {
        Navigator.of(sheetContext).pop();
        _showMemberForm(context);
      },
      onImport: () {
        Navigator.of(sheetContext).pop();
        _startContactImport(context);
      },
    ),
  );
}

class _AddMemberChoiceSheet extends StatelessWidget {
  final VoidCallback onManual;
  final VoidCallback onImport;
  const _AddMemberChoiceSheet({required this.onManual, required this.onImport});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
            'Add Member',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          _ChoiceTile(
            icon: Icons.edit_note_rounded,
            title: 'Add Manually',
            subtitle: 'Enter a name and phone number',
            onTap: onManual,
          ),
          const SizedBox(height: 12),
          if (!kIsWeb)
            _ChoiceTile(
              icon: Icons.contact_phone_rounded,
              title: 'Import from Contacts',
              subtitle: 'Pick one or more contacts from your phone',
              onTap: onImport,
            ),
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = onSurfaceAccent(context, AppColors.primary);
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black12.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.textSecondaryLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondaryLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
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

// --- Import from Contacts ---

/// Strips everything but digits and keeps the last 10, so a number saved
/// with a country code (e.g. "+91 98765 43210") still matches the app's
/// 10-digit phone format. Returns null if too short to be a real number.
String? _normalizedPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 10) return null;
  return digits.substring(digits.length - 10);
}

class _PickedContact {
  final String name;
  final String phone;
  const _PickedContact({required this.name, required this.phone});
}

Future<void> _startContactImport(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);

  // Permission is requested only now, at the moment of tapping "Import
  // from Contacts" — never on app start or dashboard open.
  bool granted;
  try {
    granted = await FlutterContacts.requestPermission(readonly: true);
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not request contacts permission: $e')),
    );
    return;
  }
  if (!granted) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Contacts permission was not granted, so contacts could not be read.',
        ),
      ),
    );
    return;
  }

  List<Contact> contacts;
  try {
    contacts = await FlutterContacts.getContacts(withProperties: true);
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not read contacts: $e')),
    );
    return;
  }

  final withPhones = contacts.where((c) => c.phones.isNotEmpty).toList()
    ..sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );

  if (withPhones.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('No contacts with a phone number were found.'),
      ),
    );
    return;
  }

  if (!context.mounted) return;
  final picked = await Navigator.of(context).push<List<_PickedContact>>(
    MaterialPageRoute(
      builder: (_) => _ContactPickerScreen(contacts: withPhones),
    ),
  );
  if (picked == null || picked.isEmpty || !context.mounted) return;

  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => _ImportPreviewScreen(picked: picked)),
  );
}

/// In-app multi-select contact list — used instead of the OS picker because
/// neither Android's nor iOS's native contact picker supports selecting more
/// than one contact reliably, and this keeps the picker on-theme with the
/// rest of the app.
class _ContactPickerScreen extends StatefulWidget {
  final List<Contact> contacts;
  const _ContactPickerScreen({required this.contacts});

  @override
  State<_ContactPickerScreen> createState() => _ContactPickerScreenState();
}

class _ContactPickerScreenState extends State<_ContactPickerScreen> {
  final _searchController = TextEditingController();
  final Set<String> _selectedIds = {};
  final Map<String, String> _chosenPhone = {};

  late final Map<String, List<String>> _validPhonesByContact;
  late final List<Contact> _eligibleContacts;

  @override
  void initState() {
    super.initState();
    _validPhonesByContact = {
      for (final c in widget.contacts)
        c.id: [
          for (final p in c.phones)
            if (_normalizedPhone(p.number) != null) _normalizedPhone(p.number)!,
        ],
    };
    _eligibleContacts = widget.contacts
        .where((c) => (_validPhonesByContact[c.id] ?? const []).isNotEmpty)
        .toList();
    for (final c in _eligibleContacts) {
      _chosenPhone[c.id] = _validPhonesByContact[c.id]!.first;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggle(String id) {
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  void _confirm() {
    final result = [
      for (final c in _eligibleContacts)
        if (_selectedIds.contains(c.id))
          _PickedContact(
            name: c.displayName.trim().isEmpty
                ? 'Unknown'
                : c.displayName.trim(),
            phone: _chosenPhone[c.id]!,
          ),
    ];
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final visible = _eligibleContacts
        .where(
          (c) => query.isEmpty || c.displayName.toLowerCase().contains(query),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedIds.isEmpty
              ? 'Select Contacts'
              : '${_selectedIds.length} selected',
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search contacts',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(_searchController.clear),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (widget.contacts.length > _eligibleContacts.length)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${widget.contacts.length - _eligibleContacts.length} contact(s) hidden — no valid phone number.',
                    style: TextStyle(
                      color: AppColors.textSecondaryLight,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Text(
                        'No matching contacts',
                        style: TextStyle(color: AppColors.textSecondaryLight),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final c = visible[index];
                        final phones = _validPhonesByContact[c.id]!;
                        final checked = _selectedIds.contains(c.id);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: checked
                                ? AppColors.primary.withValues(alpha: 0.06)
                                : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: checked
                                  ? AppColors.primary
                                  : Colors.black12.withValues(alpha: 0.06),
                              width: checked ? 1.3 : 1,
                            ),
                          ),
                          child: CheckboxListTile(
                            value: checked,
                            onChanged: (_) => _toggle(c.id),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              c.displayName.trim().isEmpty
                                  ? 'No name'
                                  : c.displayName.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: phones.length > 1
                                ? DropdownButton<String>(
                                    value: _chosenPhone[c.id],
                                    isDense: true,
                                    underline: const SizedBox.shrink(),
                                    items: [
                                      for (final p in phones)
                                        DropdownMenuItem(
                                          value: p,
                                          child: Text(p),
                                        ),
                                    ],
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(
                                        () => _chosenPhone[c.id] = value,
                                      );
                                    },
                                  )
                                : Text(phones.first),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: PrimaryButton(
          label: _selectedIds.isEmpty
              ? 'Select contacts to continue'
              : 'Continue (${_selectedIds.length})',
          onPressed: _selectedIds.isEmpty ? null : _confirm,
        ),
      ),
    );
  }
}

class _ImportRow {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final Member? existingMatch;
  bool updateExisting = false;
  _ImportRow({
    required this.nameController,
    required this.phoneController,
    required this.existingMatch,
  });
}

/// Preview screen shown before anything is saved: the Admin can edit each
/// name/phone, drop individual contacts, and for anything that already
/// matches a Member in their roster, choose to keep it as-is or update it.
class _ImportPreviewScreen extends StatefulWidget {
  final List<_PickedContact> picked;
  const _ImportPreviewScreen({required this.picked});

  @override
  State<_ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends State<_ImportPreviewScreen> {
  bool _loading = true;
  bool _saving = false;
  final List<_ImportRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final dataService = context.read<DataService>();
    var existing = const <Member>[];
    try {
      existing = await dataService.membersOnce();
    } catch (_) {
      // The duplicate check is a convenience; if it fails, fall through and
      // treat every picked contact as new rather than blocking the import.
    }
    final byPhone = {for (final m in existing) m.phone: m};

    for (final c in widget.picked) {
      _rows.add(
        _ImportRow(
          nameController: TextEditingController(text: c.name),
          phoneController: TextEditingController(text: c.phone),
          existingMatch: byPhone[c.phone],
        ),
      );
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.nameController.dispose();
      row.phoneController.dispose();
    }
    super.dispose();
  }

  void _removeRow(_ImportRow row) {
    setState(() {
      _rows.remove(row);
      row.nameController.dispose();
      row.phoneController.dispose();
    });
  }

  Future<void> _save() async {
    final newMembers = <({String name, String phone})>[];
    final updatedMembers = <({String id, String name, String phone})>[];

    for (final row in _rows) {
      final name = row.nameController.text.trim();
      final phone = row.phoneController.text.trim();
      if (name.isEmpty || phone.length != 10) continue;

      if (row.existingMatch != null) {
        if (row.updateExisting) {
          updatedMembers.add((
            id: row.existingMatch!.id,
            name: name,
            phone: phone,
          ));
        }
      } else {
        newMembers.add((name: name, phone: phone));
      }
    }

    if (newMembers.isEmpty && updatedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nothing to add — review the selected contacts.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final dataService = context.read<DataService>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final addedCount = newMembers.length;
    final updatedCount = updatedMembers.length;

    try {
      await dataService.importMembers(
        newMembers: newMembers,
        updatedMembers: updatedMembers,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not import members: $e')),
      );
      return;
    }

    if (!mounted) return;
    navigator.pop();
    final parts = <String>[
      if (addedCount > 0) '$addedCount added',
      if (updatedCount > 0) '$updatedCount updated',
    ];
    messenger.showSnackBar(
      SnackBar(
        content: Text(parts.isEmpty ? 'Import complete' : parts.join(', ')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Contacts')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _rows.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No contacts left to import',
                    style: TextStyle(color: AppColors.textSecondaryLight),
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                itemCount: _rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _ImportRowTile(
                  row: _rows[index],
                  onRemove: () => _removeRow(_rows[index]),
                ),
              ),
      ),
      bottomNavigationBar: _rows.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: PrimaryButton(
                label: 'Add Selected Members',
                onPressed: _save,
                loading: _saving,
              ),
            ),
    );
  }
}

class _ImportRowTile extends StatefulWidget {
  final _ImportRow row;
  final VoidCallback onRemove;
  const _ImportRowTile({required this.row, required this.onRemove});

  @override
  State<_ImportRowTile> createState() => _ImportRowTileState();
}

class _ImportRowTileState extends State<_ImportRowTile> {
  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final isExisting = row.existingMatch != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (isExisting ? AppColors.warning : AppColors.success)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isExisting ? 'Existing' : 'New',
                  style: TextStyle(
                    color: isExisting ? AppColors.warning : AppColors.success,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                color: AppColors.textSecondaryLight,
                visualDensity: VisualDensity.compact,
                onPressed: widget.onRemove,
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppTextField(
            controller: row.nameController,
            label: 'Name',
            icon: Icons.person_outline_rounded,
            inputFormatters: [FirstLetterCapitalizeFormatter()],
          ),
          const SizedBox(height: 10),
          AppTextField(
            controller: row.phoneController,
            label: 'Phone number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 10,
          ),
          if (isExisting) ...[
            const SizedBox(height: 8),
            Text(
              'Matches an existing member'
              '${row.existingMatch!.name.trim().isEmpty ? '' : ' (${row.existingMatch!.name})'}.',
              style: TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Keep Existing')),
                ButtonSegment(value: true, label: Text('Update')),
              ],
              selected: {row.updateExisting},
              onSelectionChanged: (selection) =>
                  setState(() => row.updateExisting = selection.first),
            ),
          ],
        ],
      ),
    );
  }
}
