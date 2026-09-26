import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../theme/app_theme.dart';
import '../utils/text_formatters.dart';
import 'app_text_field.dart';
import 'primary_button.dart';

/// The shared "Add manually vs. Import from Contacts" flow, used by the
/// Admin's Members roster and by Person Data. Each screen supplies how to
/// read its existing entries (for the duplicate check) and how to save.

/// An existing name/phone entry, used to flag duplicates during import.
typedef ContactEntry = ({String id, String name, String phone});
typedef NewContact = ({String name, String phone});

/// Saves an import in one go: brand-new entries plus existing ones the user
/// chose to overwrite.
typedef ContactImportSaver =
    Future<void> Function({
      required List<NewContact> added,
      required List<ContactEntry> updated,
    });

/// Wording for one kind of entry, e.g. `ContactImportLabels('Member',
/// 'Members')`.
class ContactImportLabels {
  final String singular;
  final String plural;
  const ContactImportLabels(this.singular, this.plural);
}

// --- Add: manual entry vs. import from contacts ---

/// Bottom sheet offering "Add Manually" or "Import from Contacts" (the
/// latter hidden on web, where there is no contacts access).
void showAddChoiceSheet(
  BuildContext context, {
  required String title,
  required VoidCallback onManual,
  required VoidCallback onImport,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _AddChoiceSheet(
      title: title,
      onManual: () {
        Navigator.of(sheetContext).pop();
        onManual();
      },
      onImport: () {
        Navigator.of(sheetContext).pop();
        onImport();
      },
    ),
  );
}

class _AddChoiceSheet extends StatelessWidget {
  final String title;
  final VoidCallback onManual;
  final VoidCallback onImport;
  const _AddChoiceSheet({
    required this.title,
    required this.onManual,
    required this.onImport,
  });

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
            title,
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

// --- Import from Contacts ---

/// Strips everything but digits and keeps the last 10, so a number saved
/// with a country code (e.g. "+91 98765 43210") still matches the app's
/// 10-digit phone format. Returns null if too short to be a real number.
String? _normalizedPhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 10) return null;
  return digits.substring(digits.length - 10);
}

/// Asks for contacts permission, lets the user multi-select contacts, then
/// shows an editable preview (with duplicate handling) before saving.
Future<void> startContactImport(
  BuildContext context, {
  required ContactImportLabels labels,
  required Future<List<ContactEntry>> Function() loadExisting,
  required ContactImportSaver save,
}) async {
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
  final picked = await Navigator.of(context).push<List<NewContact>>(
    MaterialPageRoute(
      builder: (_) => _ContactPickerScreen(contacts: withPhones),
    ),
  );
  if (picked == null || picked.isEmpty || !context.mounted) return;

  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _ImportPreviewScreen(
        picked: picked,
        labels: labels,
        loadExisting: loadExisting,
        save: save,
      ),
    ),
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
    final result = <NewContact>[
      for (final c in _eligibleContacts)
        if (_selectedIds.contains(c.id))
          (
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
  final ContactEntry? existingMatch;
  bool updateExisting = false;
  _ImportRow({
    required this.nameController,
    required this.phoneController,
    required this.existingMatch,
  });
}

/// Preview screen shown before anything is saved: the user can edit each
/// name/phone, drop individual contacts, and for anything that already
/// matches an existing entry, choose to keep it as-is or update it.
class _ImportPreviewScreen extends StatefulWidget {
  final List<NewContact> picked;
  final ContactImportLabels labels;
  final Future<List<ContactEntry>> Function() loadExisting;
  final ContactImportSaver save;

  const _ImportPreviewScreen({
    required this.picked,
    required this.labels,
    required this.loadExisting,
    required this.save,
  });

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
    var existing = const <ContactEntry>[];
    try {
      existing = await widget.loadExisting();
    } catch (_) {
      // The duplicate check is a convenience; if it fails, fall through and
      // treat every picked contact as new rather than blocking the import.
    }
    final byPhone = {for (final e in existing) e.phone: e};

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
    final added = <NewContact>[];
    final updated = <ContactEntry>[];

    for (final row in _rows) {
      final name = row.nameController.text.trim();
      final phone = row.phoneController.text.trim();
      if (name.isEmpty || phone.length != 10) continue;

      if (row.existingMatch != null) {
        if (row.updateExisting) {
          updated.add((id: row.existingMatch!.id, name: name, phone: phone));
        }
      } else {
        added.add((name: name, phone: phone));
      }
    }

    if (added.isEmpty && updated.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nothing to add — review the selected contacts.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await widget.save(added: added, updated: updated);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Could not import ${widget.labels.plural.toLowerCase()}: $e',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    navigator.pop();
    final parts = <String>[
      if (added.isNotEmpty) '${added.length} added',
      if (updated.isNotEmpty) '${updated.length} updated',
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
                  singularLabel: widget.labels.singular,
                  onRemove: () => _removeRow(_rows[index]),
                ),
              ),
      ),
      bottomNavigationBar: _rows.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: PrimaryButton(
                label: 'Add Selected ${widget.labels.plural}',
                onPressed: _save,
                loading: _saving,
              ),
            ),
    );
  }
}

class _ImportRowTile extends StatefulWidget {
  final _ImportRow row;
  final String singularLabel;
  final VoidCallback onRemove;
  const _ImportRowTile({
    required this.row,
    required this.singularLabel,
    required this.onRemove,
  });

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
              'Matches an existing ${widget.singularLabel.toLowerCase()}'
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
