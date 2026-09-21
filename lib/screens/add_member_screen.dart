import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/event_booking.dart';
import '../models/event_type.dart';
import '../models/person.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../utils/text_formatters.dart';
import '../widgets/app_text_field.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/payment_chips.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_center.dart';
import '../widgets/searchable_dropdown_field.dart';
import 'add_event_screen.dart';

/// Admin/Super Admin only: an event must be created first, then Member
/// accounts are added and allocated to that specific event.
/// Create Event -> Event appears -> Select Event -> Add Members.
class AddMemberScreen extends StatelessWidget {
  const AddMemberScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = context.read<DataService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Add Members')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: paymentOrange,
        foregroundColor: Colors.white,
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const _AddEventSheet(),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Event'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<EventBooking>>(
          stream: dataService.pendingEvents(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final events = snapshot.data ?? const <EventBooking>[];
            debugPrint(
              '[DEBUG add_members_page] pendingEvents() emitted '
              '${events.length} events: '
              '${events.map((e) => '${e.id.substring(0, 6)}:${e.eventName}:${e.date}:${e.status}').toList()}',
            );
            if (events.isEmpty) {
              return const _NoEventsCard();
            }

            final groups = _groupByDate(events);
            final totalMembers = events.fold<int>(
              0,
              (sum, e) => sum + e.assignedMembers.length,
            );
            final stillNeeded = events.fold<int>(
              0,
              (sum, e) =>
                  sum +
                  (e.requiredMembers - e.assignedMembers.length).clamp(
                    0,
                    e.requiredMembers,
                  ),
            );

            return ResponsiveCenter(
              maxWidth: 640,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  _AllocationStatsRow(
                    eventCount: events.length,
                    memberCount: totalMembers,
                    stillNeeded: stillNeeded,
                  ),
                  const SizedBox(height: 22),
                  for (final group in groups) ...[
                    _DateSectionLabel(date: group.date),
                    const SizedBox(height: 10),
                    for (final event in group.events) ...[
                      _EventAllocationCard(event: event),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DateGroup {
  final DateTime date;
  final List<EventBooking> events;
  const _DateGroup(this.date, this.events);
}

List<_DateGroup> _groupByDate(List<EventBooking> events) {
  final groups = <_DateGroup>[];
  for (final event in events) {
    final day = DateTime(event.date.year, event.date.month, event.date.day);
    if (groups.isNotEmpty && _isSameDate(groups.last.date, day)) {
      groups.last.events.add(event);
    } else {
      groups.add(_DateGroup(day, [event]));
    }
  }
  return groups;
}

bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _dateSectionLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  if (_isSameDate(date, today)) return 'Today';
  if (_isSameDate(date, tomorrow)) return 'Tomorrow';
  return formatEventDate(date);
}

/// Compact hero row summarizing how many events are awaiting members, how
/// many members have been allocated so far, and how many are still needed —
/// at a glance.
class _AllocationStatsRow extends StatelessWidget {
  final int eventCount;
  final int memberCount;
  final int stillNeeded;
  const _AllocationStatsRow({
    required this.eventCount,
    required this.memberCount,
    required this.stillNeeded,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatChip(
            icon: Icons.event_note_rounded,
            label: 'Events',
            value: '$eventCount',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatChip(
            icon: Icons.groups_rounded,
            label: 'Allocated',
            value: '$memberCount',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatChip(
            icon: Icons.person_search_rounded,
            label: 'Still Needed',
            value: '$stillNeeded',
            highlight: stillNeeded > 0,
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool highlight;
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        gradient: highlight
            ? const LinearGradient(
                colors: [AppColors.danger, Color(0xFFB33A2E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [paymentOrange, paymentOrangeDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (highlight ? AppColors.danger : paymentOrangeDark)
                .withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(height: 9),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateSectionLabel extends StatelessWidget {
  final DateTime date;
  const _DateSectionLabel({required this.date});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 12,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 6),
              Text(
                _dateSectionLabel(date),
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: Colors.black12.withValues(alpha: 0.5))),
      ],
    );
  }
}

class _NoEventsCard extends StatelessWidget {
  const _NoEventsCard();

  @override
  Widget build(BuildContext context) {
    return ResponsiveCenter(
      maxWidth: 640,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.black12.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_note_rounded,
                  color: AppColors.secondary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No events created yet',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap "Add Event" to create one, then add members to it.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondaryLight),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An event's allocation card: who called, event type/name, date & shift,
/// and the members already allocated to it — with an action to add more.
class _EventAllocationCard extends StatelessWidget {
  final EventBooking event;
  const _EventAllocationCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final hasTarget = event.requiredMembers > 0;
    final isFull =
        hasTarget && event.assignedMembers.length >= event.requiredMembers;
    final accentColor = !hasTarget
        ? Colors.black12
        : isFull
        ? AppColors.success
        : paymentOrange;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black12.withValues(alpha: 0.05)),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: accentColor.withValues(alpha: 0.6)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: paymentOrange.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.event_note_rounded,
                                color: paymentOrange,
                                size: 22,
                              ),
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
                                      fontSize: 16,
                                      color: AppColors.textPrimaryLight,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    event.eventType,
                                    style: const TextStyle(
                                      color: AppColors.textSecondaryLight,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 19,
                                      ),
                                      color: AppColors.textSecondaryLight,
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _editEvent(context),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 19,
                                      ),
                                      color: AppColors.danger,
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _deleteEvent(context),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                ShiftBadge(shift: event.shift),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 26),
                        Row(
                          children: [
                            const Icon(
                              Icons.call_outlined,
                              size: 15,
                              color: AppColors.textSecondaryLight,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Called by ${event.personName}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondaryLight,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 14,
                              color: AppColors.textSecondaryLight,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              formatEventDate(event.date),
                              style: const TextStyle(
                                color: AppColors.textSecondaryLight,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Text(
                              event.requiredMembers > 0
                                  ? 'Allocated members'
                                  : 'Allocated members (${event.assignedMembers.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12.5,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                            if (event.requiredMembers > 0) ...[
                              const SizedBox(width: 8),
                              _MemberProgressBadge(
                                assigned: event.assignedMembers.length,
                                required: event.requiredMembers,
                              ),
                            ],
                          ],
                        ),
                        if (hasTarget) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: LinearProgressIndicator(
                              value:
                                  (event.assignedMembers.length /
                                          event.requiredMembers)
                                      .clamp(0, 1)
                                      .toDouble(),
                              minHeight: 6,
                              backgroundColor: Colors.black12.withValues(
                                alpha: 0.06,
                              ),
                              valueColor: AlwaysStoppedAnimation(accentColor),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        if (event.assignedMembers.isEmpty)
                          Text(
                            'No members added yet',
                            style: TextStyle(
                              color: AppColors.textSecondaryLight.withValues(
                                alpha: 0.8,
                              ),
                              fontSize: 12.5,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final member in event.assignedMembers)
                                Chip(
                                  avatar: const Icon(
                                    Icons.person_rounded,
                                    size: 16,
                                  ),
                                  label: Text(member.name),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: amountChipBg,
                                ),
                            ],
                          ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => _AddMemberSheet(event: event),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: paymentOrangeDark,
                              side: const BorderSide(color: paymentOrange),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: const Text(
                              'Add Members to Event',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editEvent(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Event'),
        content: const Text('Do you want to edit this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AddEventScreen(existing: event)));
  }

  Future<void> _deleteEvent(BuildContext context) async {
    final confirmed = await confirmDelete(context);
    if (!confirmed || !context.mounted) return;

    await context.read<DataService>().deleteEventBooking(event.id);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event deleted')));
    }
  }
}

/// A titled card grouping related fields — mirrors the main Add Event
/// screen's section styling so this quick-create sheet feels consistent.
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
    final accent = onSurfaceAccent(context, paymentOrange);
    return Container(
      padding: const EdgeInsets.all(14),
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
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 15, color: accent),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

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

/// Quick "create event" form: who called, event type, event name, date &
/// shift. Location & amount are auto-filled from the matching Event Details
/// (Manage Data) record, exactly as the main Add Event screen does.
class _AddEventSheet extends StatefulWidget {
  const _AddEventSheet();

  @override
  State<_AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<_AddEventSheet> {
  String? _selectedTypeId;
  String? _selectedTypeName;
  String? _selectedEventName;
  Shift? _shift;
  DateTime _date = DateTime.now();
  String? _selectedPersonId;
  String? _selectedPersonName;
  final _memberCountController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _memberCountController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')} ${_months[date.month - 1]} ${date.year}';
  }

  Future<void> _save() async {
    if (_selectedPersonId == null) {
      _showMessage('Select the Person Who Called');
      return;
    }
    if (_selectedTypeId == null || _selectedEventName == null) {
      _showMessage('Select an Event Type and Event Name');
      return;
    }
    if (_shift == null) {
      _showMessage('Select a Shift');
      return;
    }
    final memberCount = int.tryParse(_memberCountController.text.trim());
    if (memberCount == null || memberCount < 1) {
      _showMessage('Enter how many members are needed');
      return;
    }

    setState(() => _saving = true);
    final dataService = context.read<DataService>();
    final messenger = ScaffoldMessenger.of(context);
    final date = DateTime(_date.year, _date.month, _date.day);

    try {
      final record = await dataService.findEventRecord(
        eventTypeId: _selectedTypeId!,
        eventName: _selectedEventName!,
      );
      if (record == null) {
        setState(() => _saving = false);
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'No Address/Amount found for this event. Add it under Manage Data → Event Details first.',
            ),
          ),
        );
        return;
      }

      final results = await Future.wait([
        dataService.eventNameBelongsToType(
          _selectedTypeId!,
          _selectedEventName!,
        ),
        dataService.checkBookingSlot(
          eventType: _selectedTypeName!,
          eventName: _selectedEventName!,
          date: date,
          shift: _shift!,
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

      final amount = _shift == Shift.day
          ? record.dayAmount
          : record.nightAmount;

      final newBooking = EventBooking(
        id: '',
        eventTypeId: _selectedTypeId!,
        eventType: _selectedTypeName!,
        eventName: _selectedEventName!,
        shift: _shift!,
        date: date,
        personId: _selectedPersonId!,
        personName: _selectedPersonName!,
        location: record.location,
        amount: amount,
        requiredMembers: memberCount,
      );
      debugPrint(
        '[DEBUG add_event_sheet] saving booking: date=$date '
        'status=${newBooking.status} shift=${newBooking.shift} '
        'eventType=${newBooking.eventType} eventName=${newBooking.eventName} '
        'uid=${fb.FirebaseAuth.instance.currentUser?.uid}',
      );
      await dataService.addEventBooking(newBooking);
      debugPrint('[DEBUG add_event_sheet] addEventBooking() completed');

      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(content: Text('Event created')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataService = context.read<DataService>();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
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
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: paymentOrange.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.event_note_rounded,
                      color: paymentOrange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Event',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Create it, then allocate members to it',
                          style: TextStyle(
                            color: AppColors.textSecondaryLight,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _FormSection(
                title: 'Contact Information',
                icon: Icons.contact_phone_outlined,
                children: [
                  StreamBuilder<List<Person>>(
                    stream: dataService.people(),
                    builder: (context, snapshot) {
                      final people = snapshot.data ?? const <Person>[];
                      if (people.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.12),
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
                          final matches = people.where((p) => p.id == value);
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
              const SizedBox(height: 12),
              _FormSection(
                title: 'Event Information',
                icon: Icons.event_rounded,
                children: [
                  StreamBuilder<List<EventType>>(
                    stream: dataService.eventTypes(),
                    builder: (context, snapshot) {
                      final types = snapshot.data ?? const <EventType>[];
                      if (types.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Text(
                            'No event types found. Add one from Manage Data → Event Details first.',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        );
                      }
                      final typeMatches = types.where(
                        (t) => t.id == _selectedTypeId,
                      );
                      final eventNames = typeMatches.isEmpty
                          ? const <String>[]
                          : typeMatches.first.eventNames;
                      final eventNameValue =
                          eventNames.contains(_selectedEventName)
                          ? _selectedEventName
                          : null;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                              final matches = types.where((t) => t.id == value);
                              setState(() {
                                _selectedTypeId = value;
                                _selectedTypeName = matches.isEmpty
                                    ? null
                                    : matches.first.name;
                                _selectedEventName = null;
                              });
                            },
                          ),
                          const SizedBox(height: 14),
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
                                SearchableDropdownOption(value: n, label: n),
                            ],
                            onSelected: _selectedTypeId == null
                                ? (_) {}
                                : (value) => setState(
                                    () => _selectedEventName = value,
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date *',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(_formatDate(_date)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Shift *',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
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
                    selected: _shift == null ? <Shift>{} : <Shift>{_shift!},
                    emptySelectionAllowed: true,
                    onSelectionChanged: (selection) => setState(
                      () => _shift = selection.isEmpty ? null : selection.first,
                    ),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: _memberCountController,
                    label: 'How Many Members *',
                    hint: 'e.g. 3',
                    icon: Icons.groups_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 3,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Create Event',
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

/// Lets the admin pick from the existing Member/Admin roster to allocate to
/// [event].
class _AddMemberSheet extends StatefulWidget {
  final EventBooking event;
  const _AddMemberSheet({required this.event});

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _searchController = TextEditingController();
  final Map<String, String> _selected = {};
  UserRole? _roleFilter;
  bool _nearbyOnly = false;
  bool _saving = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addSelected() async {
    if (_selected.isEmpty) return;
    setState(() => _saving = true);

    final dataService = context.read<DataService>();
    final messenger = ScaffoldMessenger.of(context);
    final count = _selected.length;

    try {
      await dataService.assignMembersToEvent(
        widget.event.id,
        members: [
          for (final entry in _selected.entries)
            (id: entry.key, name: entry.value),
        ],
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          count == 1
              ? '1 member added to ${widget.event.eventName}'
              : '$count members added to ${widget.event.eventName}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final assignedIds = widget.event.assignedMembers.map((m) => m.id).toSet();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
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
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: paymentOrange.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: paymentOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Members to Event',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${widget.event.eventName} · ${widget.event.shift.label} Shift · ${formatEventDate(widget.event.date)}',
                      style: TextStyle(
                        color: AppColors.textSecondaryLight,
                        fontSize: 12,
                      ),
                    ),
                    if (widget.event.location.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 13,
                              color: paymentOrangeDark,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.event.location,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: paymentOrangeDark,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search members & admins',
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
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _roleFilter == null,
                  onTap: () => setState(() => _roleFilter = null),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Members',
                  selected: _roleFilter == UserRole.member,
                  onTap: () => setState(() => _roleFilter = UserRole.member),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Admins',
                  selected: _roleFilter == UserRole.admin,
                  onTap: () => setState(() => _roleFilter = UserRole.admin),
                ),
                if (widget.event.location.trim().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(width: 1, height: 20, color: Colors.black12),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Near Event',
                    icon: Icons.near_me_rounded,
                    selected: _nearbyOnly,
                    onTap: () => setState(() => _nearbyOnly = !_nearbyOnly),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _CreateNewMemberSheet(event: widget.event),
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text("Person not listed? Create new member"),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<AppUser>>(
              stream: auth.members(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final query = _searchController.text.trim().toLowerCase();
                var people = (snapshot.data ?? const <AppUser>[])
                    .where((u) => !assignedIds.contains(u.id))
                    .where(
                      (u) =>
                          query.isEmpty || u.name.toLowerCase().contains(query),
                    )
                    .where((u) => _roleFilter == null || u.role == _roleFilter)
                    .toList();

                if (_nearbyOnly) {
                  people = people
                      .where(
                        (u) => _isNearbyPlace(u.place, widget.event.location),
                      )
                      .toList();
                } else {
                  people.sort((a, b) {
                    final aNear = _isNearbyPlace(
                      a.place,
                      widget.event.location,
                    );
                    final bNear = _isNearbyPlace(
                      b.place,
                      widget.event.location,
                    );
                    if (aNear == bNear) {
                      return a.name.toLowerCase().compareTo(
                        b.name.toLowerCase(),
                      );
                    }
                    return aNear ? -1 : 1;
                  });
                }

                if (people.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people_outline_rounded,
                            size: 48,
                            color: AppColors.textSecondaryLight,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            snapshot.data == null || snapshot.data!.isEmpty
                                ? 'No members or admins yet'
                                : 'No matches for these filters',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        '${people.length} ${people.length == 1 ? 'person' : 'people'} available',
                        style: TextStyle(
                          color: AppColors.textSecondaryLight,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: people.length,
                        itemBuilder: (context, index) {
                          final person = people[index];
                          final checked = _selected.containsKey(person.id);
                          final near = _isNearbyPlace(
                            person.place,
                            widget.event.location,
                          );
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: checked
                                  ? paymentOrange.withValues(alpha: 0.08)
                                  : Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: checked
                                    ? paymentOrange
                                    : Colors.black12.withValues(alpha: 0.06),
                                width: checked ? 1.3 : 1,
                              ),
                            ),
                            child: CheckboxListTile(
                              value: checked,
                              onChanged: (value) => setState(() {
                                if (value ?? false) {
                                  _selected[person.id] = person.name;
                                } else {
                                  _selected.remove(person.id);
                                }
                              }),
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              title: Text(
                                person.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: person.place.trim().isEmpty
                                  ? null
                                  : Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_outlined,
                                          size: 12,
                                          color: AppColors.textSecondaryLight,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            person.place,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  AppColors.textSecondaryLight,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                              secondary: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _RoleBadge(role: person.role),
                                  if (near) ...[
                                    const SizedBox(height: 4),
                                    const _NearBadge(),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              0,
              12,
              0,
              12 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: PrimaryButton(
              label: _selected.isEmpty
                  ? 'Select members to add'
                  : 'Add ${_selected.length} Selected',
              onPressed: _selected.isEmpty ? null : _addSelected,
              loading: _saving,
            ),
          ),
        ],
      ),
    );
  }
}

/// Loose text-based "nearby" check between a person's registered place and
/// an event's address — this app has no geocoding, so it treats a
/// substring or shared-word match as nearby (e.g. "Moodubelle" matches
/// "Moodubelle Temple Road, Udupi").
bool _isNearbyPlace(String place, String location) {
  final p = place.trim().toLowerCase();
  final l = location.trim().toLowerCase();
  if (p.isEmpty || l.isEmpty) return false;
  if (p == l || l.contains(p) || p.contains(l)) return true;

  final pWords = p
      .split(RegExp(r'[,\-\s]+'))
      .where((w) => w.length > 2)
      .toSet();
  final lWords = l
      .split(RegExp(r'[,\-\s]+'))
      .where((w) => w.length > 2)
      .toSet();
  return pWords.intersection(lWords).isNotEmpty;
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? paymentOrange : paymentOrange.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: selected ? Colors.white : paymentOrangeDark,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : paymentOrangeDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberProgressBadge extends StatelessWidget {
  final int assigned;
  final int required;
  const _MemberProgressBadge({required this.assigned, required this.required});

  @override
  Widget build(BuildContext context) {
    final full = assigned >= required;
    final color = full ? AppColors.success : paymentOrangeDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$assigned/$required',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

class _NearBadge extends StatelessWidget {
  const _NearBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.near_me_rounded, size: 10, color: AppColors.success),
          const SizedBox(width: 3),
          Text(
            'Near',
            style: TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final UserRole role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: role.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(role.icon, size: 12, color: role.color),
          const SizedBox(width: 4),
          Text(
            role.label,
            style: TextStyle(
              color: role.color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fallback for a person who doesn't have an account yet: creates a new
/// Member account and allocates it to [event] in one step, then closes both
/// this sheet and the roster picker behind it.
class _CreateNewMemberSheet extends StatefulWidget {
  final EventBooking event;
  const _CreateNewMemberSheet({required this.event});

  @override
  State<_CreateNewMemberSheet> createState() => _CreateNewMemberSheetState();
}

class _CreateNewMemberSheetState extends State<_CreateNewMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _placeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _placeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final auth = context.read<AuthService>();
    final dataService = context.read<DataService>();
    final messenger = ScaffoldMessenger.of(context);
    final name = _nameController.text.trim();

    final result = await auth.addMember(
      name: name,
      email: _emailController.text,
      password: _passwordController.text,
      phone: _phoneController.text,
      place: _placeController.text,
    );

    if (!result.success) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(result.error!)));
      return;
    }

    try {
      await dataService.assignMemberToEvent(
        widget.event.id,
        memberId: result.userId!,
        memberName: name,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Member added but could not link to event: $e')),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // close this create-member sheet
    Navigator.of(context).pop(); // close the roster picker behind it
    messenger.showSnackBar(
      SnackBar(content: Text('$name added to ${widget.event.eventName}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                  'Create New Member',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Allocating to ${widget.event.eventName} · ${widget.event.shift.label} Shift',
                  style: TextStyle(
                    color: AppColors.textSecondaryLight,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 20),
                AppTextField(
                  controller: _nameController,
                  label: 'Full name',
                  icon: Icons.person_outline_rounded,
                  inputFormatters: [FirstLetterCapitalizeFormatter()],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!value.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _phoneController,
                  label: 'Phone number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 10,
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) return 'Phone number is required';
                    if (trimmed.length != 10) {
                      return 'Enter a valid 10-digit phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _placeController,
                  label: 'Place',
                  hint: 'Shirva, Moodubelle',
                  icon: Icons.location_on_outlined,
                  inputFormatters: [FirstLetterCapitalizeFormatter()],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Place is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'At least 6 characters',
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 6) return 'Use at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Create & Add Member',
                  onPressed: _submit,
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
