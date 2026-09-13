import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/event_booking.dart';
import '../models/event_record.dart';
import '../models/event_type.dart';
import '../models/person.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_center.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Books an event on a given date & shift, pulling Address and Amount
/// automatically from the matching Event Details (Manage Data) record.
/// Pass [existing] to edit a previously booked event instead of creating a
/// new one — the same validations are re-run before saving.
class AddEventScreen extends StatefulWidget {
  final EventBooking? existing;
  const AddEventScreen({super.key, this.existing});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  String? _selectedTypeId;
  String? _selectedTypeName;
  String? _selectedEventName;
  Shift? _shift;
  DateTime? _date;
  String? _selectedPersonId;
  String? _selectedPersonName;

  EventRecord? _matchedRecord;
  bool _loadingRecord = false;
  bool _saving = false;

  final _locationController = TextEditingController();
  final _amountController = TextEditingController();

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _selectedTypeId = existing.eventTypeId;
      _selectedTypeName = existing.eventType;
      _selectedEventName = existing.eventName;
      _shift = existing.shift;
      _date = existing.date;
      _selectedPersonId = existing.personId;
      _selectedPersonName = existing.personName;
      _locationController.text = existing.location;
      _amountController.text = formatCurrency(existing.amount);
      _loadExistingMatchedRecord();
    }
  }

  Future<void> _loadExistingMatchedRecord() async {
    setState(() => _loadingRecord = true);
    final record = await context.read<DataService>().findEventRecord(
      eventTypeId: _selectedTypeId!,
      eventName: _selectedEventName!,
    );
    if (!mounted) return;
    setState(() {
      _matchedRecord = record;
      _loadingRecord = false;
      if (record != null) {
        _locationController.text = record.location;
        _refreshAmountField();
      }
    });
  }

  @override
  void dispose() {
    _locationController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _onTypeChanged(EventType? type) {
    setState(() {
      _selectedTypeId = type?.id;
      _selectedTypeName = type?.name;
      _selectedEventName = null;
      _matchedRecord = null;
      _locationController.clear();
      _amountController.clear();
    });
  }

  Future<void> _onEventNameChanged(String? name) async {
    setState(() {
      _selectedEventName = name;
      _matchedRecord = null;
      _locationController.clear();
      _amountController.clear();
    });
    if (name == null || _selectedTypeId == null) return;

    setState(() => _loadingRecord = true);
    final record = await context.read<DataService>().findEventRecord(
      eventTypeId: _selectedTypeId!,
      eventName: name,
    );
    if (!mounted) return;
    setState(() {
      _matchedRecord = record;
      _loadingRecord = false;
      _locationController.text = record?.location ?? '';
      _refreshAmountField();
    });
  }

  void _onShiftChanged(Shift? shift) {
    setState(() {
      _shift = shift;
      _refreshAmountField();
    });
  }

  void _refreshAmountField() {
    if (_matchedRecord == null || _shift == null) {
      _amountController.text = '';
      return;
    }
    final amount = _shift == Shift.day
        ? _matchedRecord!.dayAmount
        : _matchedRecord!.nightAmount;
    _amountController.text = formatCurrency(amount);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (_selectedTypeId == null || _selectedEventName == null) {
      _showMessage('Select an Event Type and Event Name');
      return;
    }
    if (_shift == null) {
      _showMessage('Select a Shift');
      return;
    }
    if (_date == null) {
      _showMessage('Select a Date');
      return;
    }
    if (_selectedPersonId == null) {
      _showMessage('Select the Person Who Called');
      return;
    }
    if (_matchedRecord == null) {
      _showMessage(
        'No Address/Amount found for this event. Add it under Manage Data → Event Details first.',
      );
      return;
    }

    setState(() => _saving = true);
    final dataService = context.read<DataService>();
    final messenger = ScaffoldMessenger.of(context);
    final excludingId = widget.existing?.id;

    try {
      final belongsToType = await dataService.eventNameBelongsToType(
        _selectedTypeId!,
        _selectedEventName!,
      );
      if (!belongsToType) {
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

      final isDuplicate = await dataService.isDuplicateBooking(
        eventType: _selectedTypeName!,
        eventName: _selectedEventName!,
        date: _date!,
        shift: _shift!,
        excludingId: excludingId,
      );
      if (isDuplicate) {
        setState(() => _saving = false);
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'This event has already been added for this date and shift.',
            ),
          ),
        );
        return;
      }

      final slotTaken = await dataService.hasBookingForDateAndShift(
        date: _date!,
        shift: _shift!,
        excludingId: excludingId,
      );
      if (slotTaken) {
        setState(() => _saving = false);
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'You already have an event scheduled for this date and shift.',
            ),
          ),
        );
        return;
      }

      final amount = _shift == Shift.day
          ? _matchedRecord!.dayAmount
          : _matchedRecord!.nightAmount;
      final booking = EventBooking(
        id: widget.existing?.id ?? '',
        eventTypeId: _selectedTypeId!,
        eventType: _selectedTypeName!,
        eventName: _selectedEventName!,
        shift: _shift!,
        date: _date!,
        personId: _selectedPersonId!,
        personName: _selectedPersonName!,
        location: _matchedRecord!.location,
        amount: amount,
        tips: widget.existing?.tips ?? 0,
        status: widget.existing?.status ?? BookingStatus.upcoming,
      );

      if (_isEditing) {
        await dataService.updateEventBooking(widget.existing!.id, booking);
      } else {
        await dataService.addEventBooking(booking);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Event updated successfully'
                : 'Event added successfully',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')} ${_months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final dataService = context.read<DataService>();

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Event' : 'Add Event')),
      body: SafeArea(
        child: StreamBuilder<List<EventType>>(
          stream: dataService.eventTypes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final types = snapshot.data ?? const <EventType>[];
            if (types.isEmpty) {
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
                        'No event types found',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add an Event Type & Name from Manage Data → Event Details first.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondaryLight,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final typeMatches = types.where((t) => t.id == _selectedTypeId);
            final eventNames = typeMatches.isEmpty
                ? const <String>[]
                : typeMatches.first.eventNames;
            final eventNameValue = eventNames.contains(_selectedEventName)
                ? _selectedEventName
                : null;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ResponsiveCenter(
                maxWidth: 640,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FormSection(
                      title: 'Contact Information',
                      icon: Icons.contact_phone_outlined,
                      children: [
                        StreamBuilder<List<Person>>(
                          stream: dataService.people(),
                          builder: (context, personSnapshot) {
                            final people =
                                personSnapshot.data ?? const <Person>[];
                            if (people.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Text(
                                  'No people found. Add one from Manage Data → Person Data first.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                  ),
                                ),
                              );
                            }

                            final personValue =
                                people.any((p) => p.id == _selectedPersonId)
                                ? _selectedPersonId
                                : null;
                            return DropdownMenu<String>(
                              key: ValueKey('person-$personValue'),
                              initialSelection: personValue,
                              expandedInsets: EdgeInsets.zero,
                              enableFilter: true,
                              requestFocusOnTap: true,
                              label: const Text('Person Who Called *'),
                              leadingIcon: const Icon(Icons.call_outlined),
                              hintText: 'Search a person…',
                              dropdownMenuEntries: people
                                  .map(
                                    (p) => DropdownMenuEntry(
                                      value: p.id,
                                      label: p.name,
                                    ),
                                  )
                                  .toList(),
                              onSelected: (value) {
                                final matches = people.where(
                                  (p) => p.id == value,
                                );
                                setState(() {
                                  _selectedPersonId = value;
                                  _selectedPersonName = matches.isEmpty
                                      ? null
                                      : matches.first.name;
                                });
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _FormSection(
                      title: 'Event Information',
                      icon: Icons.event_note_rounded,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _selectedTypeId,
                          decoration: const InputDecoration(
                            labelText: 'Event Type *',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: types
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t.id,
                                  child: Text(t.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            final matches = types.where((t) => t.id == value);
                            _onTypeChanged(
                              matches.isEmpty ? null : matches.first,
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: eventNameValue,
                          decoration: const InputDecoration(
                            labelText: 'Event Name *',
                            prefixIcon: Icon(Icons.label_outline_rounded),
                          ),
                          items: eventNames
                              .map(
                                (n) =>
                                    DropdownMenuItem(value: n, child: Text(n)),
                              )
                              .toList(),
                          onChanged: _selectedTypeId == null
                              ? null
                              : _onEventNameChanged,
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date *',
                              prefixIcon: Icon(Icons.calendar_today_outlined),
                            ),
                            child: Text(
                              _date == null
                                  ? 'Select date'
                                  : _formatDate(_date!),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Shift *',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<Shift>(
                          segments: const [
                            ButtonSegment(
                              value: Shift.day,
                              label: Text('Day'),
                              icon: Icon(Icons.wb_sunny_outlined),
                            ),
                            ButtonSegment(
                              value: Shift.night,
                              label: Text('Night'),
                              icon: Icon(Icons.nightlight_outlined),
                            ),
                          ],
                          selected: _shift == null
                              ? <Shift>{}
                              : <Shift>{_shift!},
                          emptySelectionAllowed: true,
                          onSelectionChanged: (selection) => _onShiftChanged(
                            selection.isEmpty ? null : selection.first,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _FormSection(
                      title: 'Event Details',
                      icon: Icons.receipt_long_outlined,
                      children: [
                        TextFormField(
                          controller: _locationController,
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: 'Address / Location (auto-filled)',
                            prefixIcon: const Icon(Icons.location_on_outlined),
                            suffixIcon: _loadingRecord
                                ? const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _amountController,
                          enabled: false,
                          decoration: const InputDecoration(
                            labelText: 'Amount (auto-filled)',
                            prefixIcon: Icon(Icons.currency_rupee_rounded),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    PrimaryButton(
                      label: _isEditing ? 'Update Event' : 'Save Event',
                      onPressed: _save,
                      loading: _saving,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A titled card grouping related fields, used to organize the form into
/// Event Information / Contact Information / Event Details.
class _FormSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _FormSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final accent = onSurfaceAccent(context, AppColors.primary);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
