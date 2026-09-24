import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/event_booking.dart';
import '../models/event_record.dart';
import '../models/event_type.dart';
import '../models/person.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_center.dart';
import '../widgets/searchable_dropdown_field.dart';

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

/// Plain editable representation of a currency amount (no symbol or digit
/// grouping) — used to seed the Amount field so the user can type over it.
String _plainAmountText(double amount) {
  return amount == amount.roundToDouble()
      ? amount.toStringAsFixed(0)
      : amount.toString();
}

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
      _amountController.text = _plainAmountText(existing.amount);
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
      // Amount is left untouched here: it already holds this booking's own
      // saved amount (set in initState), which may have been edited away
      // from the Event Details default — opening Edit must not silently
      // replace it with the current master Day/Night amount.
      if (record != null) {
        _locationController.text = record.location;
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
    _amountController.text = _plainAmountText(amount);
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
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showMessage('Enter a valid Amount');
      return;
    }

    setState(() => _saving = true);
    final dataService = context.read<DataService>();
    final messenger = ScaffoldMessenger.of(context);
    final excludingId = widget.existing?.id;

    try {
      final results = await Future.wait([
        dataService.eventNameBelongsToType(
          _selectedTypeId!,
          _selectedEventName!,
        ),
        dataService.checkBookingSlot(
          eventType: _selectedTypeName!,
          eventName: _selectedEventName!,
          date: _date!,
          shift: _shift!,
          excludingId: excludingId,
        ),
      ]);
      final belongsToType = results[0] as bool;
      final slotCheck = results[1] as BookingSlotCheck;

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

      if (slotCheck.isDuplicate) {
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

      if (slotCheck.slotTaken) {
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

      // An event dated before today is already over, so it goes straight to
      // Pending Payments instead of waiting for Event Done.
      final now = DateTime.now();
      final isPastDate = _date!.isBefore(
        DateTime(now.year, now.month, now.day),
      );
      final currentStatus = widget.existing?.status ?? BookingStatus.upcoming;
      final movedToPayments =
          isPastDate && currentStatus == BookingStatus.upcoming;
      final status = movedToPayments
          ? BookingStatus.pendingPayment
          : currentStatus;

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
        status: status,
        copied: widget.existing?.copied ?? false,
        assignedMembers: widget.existing?.assignedMembers ?? const [],
        requiredMembers: widget.existing?.requiredMembers ?? 0,
        presentMemberIds: widget.existing?.presentMemberIds ?? const [],
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
            movedToPayments
                ? 'Past event saved to Pending Payments'
                : _isEditing
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

            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 480;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
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
                                    padding: const EdgeInsets.all(12),
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
                                return SearchableDropdownField<String>(
                                  key: ValueKey('person-$personValue'),
                                  value: personValue,
                                  label: 'Person Who Called *',
                                  icon: Icons.call_outlined,
                                  hintText: 'Search a person…',
                                  options: [
                                    for (final p in people)
                                      SearchableDropdownOption(
                                        value: p.id,
                                        label: p.name,
                                      ),
                                  ],
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
                        const SizedBox(height: 10),
                        _FormSection(
                          title: 'Event Information',
                          icon: Icons.event_note_rounded,
                          children: [
                            _ResponsiveFieldRow(
                              isWide: isWide,
                              spacing: 12,
                              children: [
                                SearchableDropdownField<String>(
                                  key: ValueKey('type-$_selectedTypeId'),
                                  value: _selectedTypeId,
                                  label: 'Event Type *',
                                  icon: Icons.category_outlined,
                                  hintText: 'Search an event type…',
                                  options: [
                                    for (final t in types)
                                      SearchableDropdownOption(
                                        value: t.id,
                                        label: t.name,
                                      ),
                                  ],
                                  onSelected: (value) {
                                    final matches = types.where(
                                      (t) => t.id == value,
                                    );
                                    _onTypeChanged(
                                      matches.isEmpty ? null : matches.first,
                                    );
                                  },
                                ),
                                SearchableDropdownField<String>(
                                  key: ValueKey(
                                    'name-$_selectedTypeId-$eventNameValue',
                                  ),
                                  value: eventNameValue,
                                  label: 'Event Name *',
                                  icon: Icons.label_outline_rounded,
                                  hintText: 'Search an event name…',
                                  enabled: _selectedTypeId != null,
                                  options: [
                                    for (final n in eventNames)
                                      SearchableDropdownOption(
                                        value: n,
                                        label: n,
                                      ),
                                  ],
                                  onSelected: _selectedTypeId == null
                                      ? (_) {}
                                      : _onEventNameChanged,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _ResponsiveFieldRow(
                              isWide: isWide,
                              spacing: 12,
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: _pickDate,
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Date *',
                                      prefixIcon: Icon(
                                        Icons.calendar_today_outlined,
                                      ),
                                    ),
                                    child: Text(
                                      _date == null
                                          ? 'Select date'
                                          : _formatDate(_date!),
                                    ),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Shift *',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
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
                                      onSelectionChanged: (selection) =>
                                          _onShiftChanged(
                                            selection.isEmpty
                                                ? null
                                                : selection.first,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _FormSection(
                          title: 'Event Details',
                          icon: Icons.receipt_long_outlined,
                          children: [
                            TextFormField(
                              controller: _amountController,
                              enabled: _matchedRecord != null,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'Amount *',
                                prefixIcon: const Icon(
                                  Icons.currency_rupee_rounded,
                                ),
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
                          ],
                        ),
                        const SizedBox(height: 16),
                        PrimaryButton(
                          label: _isEditing ? 'Update Event' : 'Save Event',
                          onPressed: _save,
                          loading: _saving,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Lays [children] out in a [Row] with [Expanded] cells (equally sized,
/// separated by [spacing]) when [isWide] is true, or stacked vertically with
/// [spacing] gaps otherwise — used to fit paired fields (Event Type/Name,
/// Date/Shift) on one line on wider screens while staying single-column and
/// uncramped on narrow phones.
class _ResponsiveFieldRow extends StatelessWidget {
  final bool isWide;
  final double spacing;
  final List<Widget> children;

  const _ResponsiveFieldRow({
    required this.isWide,
    required this.spacing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            Expanded(child: children[i]),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          children[i],
        ],
      ],
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: accent),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
