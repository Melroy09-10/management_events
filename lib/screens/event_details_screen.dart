import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/event_record.dart';
import '../models/event_type.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../widgets/app_text_field.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/primary_button.dart';

const _addNewValue = '__add_new__';

class EventDetailsScreen extends StatelessWidget {
  const EventDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = context.read<DataService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Event Details')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEventForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Event'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<EventRecord>>(
          stream: dataService.events(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Could not load events:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
              );
            }

            final events = snapshot.data ?? const [];
            if (events.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event_busy_rounded,
                        size: 56,
                        color: AppColors.textSecondaryLight,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No events added yet',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: events.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _EventTile(event: events[index]),
            );
          },
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final EventRecord event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final accent = onSurfaceAccent(context, AppColors.secondary);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: accent.withValues(alpha: 0.12),
                child: Icon(Icons.event_note_rounded, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.eventName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      event.eventType,
                      style: TextStyle(
                        color: AppColors.textSecondaryLight,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                color: AppColors.textSecondaryLight,
                onPressed: () => _showEventForm(context, existing: event),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                color: AppColors.danger,
                onPressed: () => _confirmDelete(context, event),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.textSecondaryLight,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(event.location, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _AmountChip(
                  label: 'Day',
                  amount: event.dayAmount,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _AmountChip(
                  label: 'Night',
                  amount: event.nightAmount,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, EventRecord event) async {
    final confirmed = await confirmDelete(context);
    if (!confirmed || !context.mounted) return;

    try {
      await context.read<DataService>().deleteEvent(event.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }
}

class _AmountChip extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _AmountChip({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            formatCurrency(amount),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

Future<void> _showEventForm(BuildContext context, {EventRecord? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EventFormSheet(existing: existing),
  );
}

class _EventFormSheet extends StatefulWidget {
  final EventRecord? existing;
  const _EventFormSheet({this.existing});

  @override
  State<_EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends State<_EventFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _locationController;
  late final TextEditingController _dayAmountController;
  late final TextEditingController _nightAmountController;

  String? _selectedTypeId;
  String? _selectedTypeName;
  String? _selectedEventName;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedTypeId = widget.existing?.eventTypeId;
    _selectedTypeName = widget.existing?.eventType;
    _selectedEventName = widget.existing?.eventName;
    _locationController = TextEditingController(
      text: widget.existing?.location ?? '',
    );
    _dayAmountController = TextEditingController(
      text: widget.existing?.dayAmount.toString() ?? '',
    );
    _nightAmountController = TextEditingController(
      text: widget.existing?.nightAmount.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _locationController.dispose();
    _dayAmountController.dispose();
    _nightAmountController.dispose();
    super.dispose();
  }

  Future<void> _promptForName({
    required String title,
    required String label,
  }) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;

    final dataService = context.read<DataService>();
    try {
      if (title == 'New Event Type') {
        final (id, canonicalName) = await dataService.addOrGetEventType(name);
        if (!mounted) return;
        setState(() {
          _selectedTypeId = id;
          _selectedTypeName = canonicalName;
          _selectedEventName = null;
        });
      } else {
        final canonicalName = await dataService.addOrGetEventName(
          _selectedTypeId!,
          name,
        );
        if (!mounted) return;
        setState(() => _selectedEventName = canonicalName);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTypeId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select an Event Type')));
      return;
    }
    if (_selectedEventName == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select an Event Name')));
      return;
    }

    setState(() => _saving = true);
    final dataService = context.read<DataService>();
    final messenger = ScaffoldMessenger.of(context);
    final location = _locationController.text.trim();

    try {
      final belongsToType = await dataService.eventNameBelongsToType(
        _selectedTypeId!,
        _selectedEventName!,
      );
      if (!belongsToType) {
        if (!mounted) return;
        setState(() => _saving = false);
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'The selected event name does not belong to this event type.',
            ),
          ),
        );
        return;
      }

      final isDuplicate = await dataService.isDuplicateEvent(
        eventType: _selectedTypeName!,
        eventName: _selectedEventName!,
        excludingId: widget.existing?.id,
      );
      if (isDuplicate) {
        if (!mounted) return;
        setState(() => _saving = false);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('This event already exists for this event type.'),
          ),
        );
        return;
      }

      final record = EventRecord(
        id: widget.existing?.id ?? '',
        eventTypeId: _selectedTypeId!,
        eventType: _selectedTypeName!,
        eventName: _selectedEventName!,
        location: location,
        dayAmount: double.parse(_dayAmountController.text.trim()),
        nightAmount: double.parse(_nightAmountController.text.trim()),
      );

      if (widget.existing == null) {
        await dataService.addEvent(record);
      } else {
        await dataService.updateEvent(widget.existing!.id, record);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.existing == null
                ? 'Event added successfully'
                : 'Event updated successfully',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final dataService = context.read<DataService>();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
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
                  isEditing ? 'Edit Event' : 'Add Event',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 20),
                StreamBuilder<List<EventType>>(
                  stream: dataService.eventTypes(),
                  builder: (context, snapshot) {
                    final types = snapshot.data ?? const <EventType>[];
                    final hasSelected =
                        _selectedTypeId != null &&
                        types.any((t) => t.id == _selectedTypeId);

                    return DropdownButtonFormField<String>(
                      initialValue: hasSelected ? _selectedTypeId : null,
                      decoration: const InputDecoration(
                        labelText: 'Event Type *',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: [
                        ...types.map(
                          (t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(t.name),
                          ),
                        ),
                        const DropdownMenuItem(
                          value: _addNewValue,
                          child: Row(
                            children: [
                              Icon(Icons.add_rounded, size: 18),
                              SizedBox(width: 6),
                              Text('Add new type'),
                            ],
                          ),
                        ),
                      ],
                      validator: (_) =>
                          _selectedTypeId == null ? 'Required' : null,
                      onChanged: (value) {
                        if (value == _addNewValue) {
                          _promptForName(
                            title: 'New Event Type',
                            label: 'Type name (e.g. Wedding)',
                          );
                          return;
                        }
                        final type = types.firstWhere((t) => t.id == value);
                        setState(() {
                          _selectedTypeId = type.id;
                          _selectedTypeName = type.name;
                          _selectedEventName = null;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                StreamBuilder<List<EventType>>(
                  stream: dataService.eventTypes(),
                  builder: (context, snapshot) {
                    final types = snapshot.data ?? const <EventType>[];
                    final typeMatches = types.where(
                      (t) => t.id == _selectedTypeId,
                    );
                    final names = typeMatches.isEmpty
                        ? const <String>[]
                        : typeMatches.first.eventNames;
                    final hasSelected =
                        _selectedEventName != null &&
                        names.contains(_selectedEventName);

                    return DropdownButtonFormField<String>(
                      initialValue: hasSelected ? _selectedEventName : null,
                      decoration: const InputDecoration(
                        labelText: 'Event Name *',
                        prefixIcon: Icon(Icons.label_outline_rounded),
                      ),
                      items: [
                        ...names.map(
                          (n) => DropdownMenuItem(value: n, child: Text(n)),
                        ),
                        const DropdownMenuItem(
                          value: _addNewValue,
                          child: Row(
                            children: [
                              Icon(Icons.add_rounded, size: 18),
                              SizedBox(width: 6),
                              Text('Add new name'),
                            ],
                          ),
                        ),
                      ],
                      validator: (_) =>
                          _selectedEventName == null ? 'Required' : null,
                      onChanged: _selectedTypeId == null
                          ? null
                          : (value) {
                              if (value == _addNewValue) {
                                _promptForName(
                                  title: 'New Event Name',
                                  label: 'Event name (e.g. Wedding Reception)',
                                );
                                return;
                              }
                              setState(() => _selectedEventName = value);
                            },
                    );
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _locationController,
                  label: 'Location *',
                  icon: Icons.location_on_outlined,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty)
                      return 'Location is required';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _dayAmountController,
                  label: 'Day Amount *',
                  icon: Icons.wb_sunny_outlined,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) return 'Day Amount is required';
                    if (double.tryParse(trimmed) == null)
                      return 'Enter a valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _nightAmountController,
                  label: 'Night Amount *',
                  icon: Icons.nightlight_outlined,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) return 'Night Amount is required';
                    if (double.tryParse(trimmed) == null)
                      return 'Enter a valid amount';
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
      ),
    );
  }
}
