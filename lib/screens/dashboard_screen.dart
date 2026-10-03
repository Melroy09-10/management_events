import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_user.dart';
import '../models/event_booking.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../widgets/app_drawer.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/payment_chips.dart';
import '../widgets/responsive_center.dart';
import 'add_event_screen.dart';
import 'add_member_screen.dart';
import 'coming_soon_screen.dart';
import 'history_screen.dart';
import 'manage_data_screen.dart';
import 'pending_events_screen.dart';
import 'pending_payments_screen.dart';

Widget _quickActionScreen(String title, IconData icon) {
  switch (title) {
    case 'Manage Data':
      return const ManageDataScreen();
    case 'Pending Events':
      return const PendingEventsScreen();
    case 'Pending Payments':
      return const PendingPaymentsScreen();
    case 'History':
      return const HistoryScreen();
    default:
      return ComingSoonScreen(title: title, icon: icon);
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  static final List<(String, IconData, Color)> _quickActions = [
    ('Manage Event', Icons.event_note_rounded, AppColors.primary),
    ('Manage Data', Icons.storage_rounded, AppColors.secondary),
    ('Pending Payments', Icons.payments_outlined, AppColors.warning),
    ('Pending Events', Icons.pending_actions_rounded, AppColors.accent),
    ('History', Icons.history_rounded, AppColors.success),
  ];

  /// Whether the Admin is on the Assigned Members tab, which decides what
  /// the Add Event button creates.
  bool _onAssignedTab = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _moveOverdueEvents();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-run when the app comes back to the foreground, so events from a day
  // that ended while the app sat in the background also move over.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _moveOverdueEvents();
  }

  /// Events from a past day that were never marked Done go to Pending
  /// Payments on their own. Best-effort: a failure (e.g. offline) just
  /// leaves them for the next run.
  Future<void> _moveOverdueEvents() async {
    try {
      await context.read<DataService>().moveOverdueEventsToPendingPayments();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser!;
    final role = user.role;

    return Scaffold(
      drawer: const AppDrawer(),
      // On the Admin's Assigned Members tab this creates a staffing event
      // (ADMIN section's Add Event); everywhere else the user's own booking.
      floatingActionButton: DashAddEventButton(
        onPressed: () => _onAssignedTab
            ? showAddStaffingEventSheet(context)
            : Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AddEventScreen())),
      ),
      body: Column(
        children: [
          Builder(
            builder: (context) => DashboardHeader(
              title: 'Dashboard',
              subtitle: 'Welcome back!',
              onMenu: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: role == UserRole.superAdmin
                  ? _SuperAdminDashboardBody(
                      user: user,
                      quickActions: _quickActions,
                    )
                  : _TodaysEventsBody(
                      isAdmin: role == UserRole.admin,
                      onPageChanged: (page) =>
                          setState(() => _onAssignedTab = page == 1),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuperAdminDashboardBody extends StatelessWidget {
  final AppUser user;
  final List<(String, IconData, Color)> quickActions;
  const _SuperAdminDashboardBody({
    required this.user,
    required this.quickActions,
  });

  @override
  Widget build(BuildContext context) {
    final role = user.role;
    return ResponsiveCenter(
      maxWidth: 760,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    user.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: _RoleBadgeCard(role: role, email: user.email),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.grid_view_rounded,
                      color: AppColors.secondary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Quick actions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.35,
              ),
              delegate: SliverChildListDelegate(
                quickActions
                    .map(
                      (action) => _QuickActionCard(
                        icon: action.$2,
                        label: action.$1,
                        color: action.$3,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                _quickActionScreen(action.$1, action.$2),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown only to Admin & User: the summary cards and the day's events
/// booked on the current user's own account (Add Event → event_bookings),
/// for today by default or any date picked from the date selector.
///
/// For an Admin, the list swipes (or taps) between two tabs: their own
/// events, and the members assigned to that day's staffing events.
class _TodaysEventsBody extends StatefulWidget {
  final bool isAdmin;
  final ValueChanged<int>? onPageChanged;
  const _TodaysEventsBody({required this.isAdmin, this.onPageChanged});

  @override
  State<_TodaysEventsBody> createState() => _TodaysEventsBodyState();
}

class _TodaysEventsBodyState extends State<_TodaysEventsBody> {
  DateTime _date = DateUtils.dateOnly(DateTime.now());

  // Held in state so switching tabs doesn't resubscribe and flash loading;
  // only replaced when the date changes.
  late Stream<List<EventBooking>> _myEvents;
  late Stream<List<EventBooking>> _staffingEvents;

  /// 0 = My Events, 1 = Assigned Members (Admin only).
  int _page = 0;

  bool get _isToday => DateUtils.isSameDay(_date, DateTime.now());

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    final dataService = context.read<DataService>();
    _myEvents = dataService.eventBookingsForDate(_date);
    _staffingEvents = dataService.staffingEventsForDate(_date);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = DateUtils.dateOnly(picked);
      _listen();
    });
  }

  void _goTo(int page) {
    if (page == _page) return;
    setState(() => _page = page);
    widget.onPageChanged?.call(page);
  }

  void _onSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -250) _goTo(1);
    if (velocity > 250) _goTo(0);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EventBooking>>(
      stream: _myEvents,
      builder: (context, mine) {
        if (!widget.isAdmin) return _content(context, mine, null);
        return StreamBuilder<List<EventBooking>>(
          stream: _staffingEvents,
          builder: (context, staffing) => _content(context, mine, staffing),
        );
      },
    );
  }

  Widget _content(
    BuildContext context,
    AsyncSnapshot<List<EventBooking>> mine,
    AsyncSnapshot<List<EventBooking>>? staffing,
  ) {
    final dataService = context.read<DataService>();
    final events = mine.data ?? const <EventBooking>[];
    // Only Admin-created (staffing) events take members — user bookings
    // never appear here. Events with nobody assigned are left out.
    final assignedEvents = [
      for (final e in staffing?.data ?? const <EventBooking>[])
        if (e.assignedMembers.isNotEmpty) e,
    ];
    final showingAssigned = widget.isAdmin && _page == 1;
    final loading = showingAssigned
        ? staffing?.connectionState == ConnectionState.waiting
        : mine.connectionState == ConnectionState.waiting;
    final counts = _ShiftCounts.of(showingAssigned ? assignedEvents : events);

    return ResponsiveCenter(
      maxWidth: 760,
      child: GestureDetector(
        onHorizontalDragEnd: widget.isAdmin ? _onSwipe : null,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    // Title + count shrink to fit rather than being cut off
                    // ("Today' …") next to the date selector.
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              showingAssigned
                                  ? 'Assigned Members'
                                  : (_isToday ? "Today's Events" : 'Events'),
                              maxLines: 1,
                              style: TextStyle(
                                color: DashColors.textPrimary(context),
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(width: 10),
                            DashCountBadge(
                              count: showingAssigned
                                  ? assignedEvents.length
                                  : events.length,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DashDateSelector(date: _date, onTap: _pickDate),
                  ],
                ),
              ),
            ),
            if (widget.isAdmin)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                sliver: SliverToBoxAdapter(
                  child: DashEventTabs(
                    selected: _page,
                    onChanged: _goTo,
                    tabs: const [
                      DashTab(Icons.calendar_month_rounded, 'My Events'),
                      DashTab(Icons.groups_rounded, 'Assigned Members'),
                    ],
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              sliver: SliverToBoxAdapter(
                child: _ShiftSummaryRow(
                  counts: counts,
                  assigned: showingAssigned,
                ),
              ),
            ),
            if (loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (showingAssigned && assignedEvents.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                sliver: SliverToBoxAdapter(
                  child: DashEmptyCard(
                    icon: Icons.group_off_rounded,
                    message: 'No events with assigned members for this date.',
                  ),
                ),
              )
            else if (showingAssigned)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                sliver: SliverList.separated(
                  itemCount: assignedEvents.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final event = assignedEvents[index];
                    return _AssignedEventCard(
                      event: event,
                      onViewDetails: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _EventMembersScreen(event: event),
                        ),
                      ),
                    );
                  },
                ),
              )
            else if (events.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                sliver: SliverToBoxAdapter(
                  child: DashEmptyCard(
                    icon: Icons.event_available_rounded,
                    message: 'No events scheduled for this date.',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final event = events[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TodaysEventCard(
                        event: event,
                        onEditTips: (tips) =>
                            dataService.updateEventTips(event.id, tips),
                        onEditAmount: (amount) =>
                            dataService.updateEventAmount(event.id, amount),
                        onPaymentDone: () async {
                          await dataService.markBookingDone(event.id);
                          _showMessage('Moved to Pending Payments');
                        },
                        onEdit: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AddEventScreen(existing: event),
                          ),
                        ),
                        onCancel: () async {
                          final confirmed = await confirmDelete(context);
                          if (!confirmed || !context.mounted) return;
                          await dataService.deleteEventBooking(event.id);
                          _showMessage('Event cancelled');
                        },
                      ),
                    );
                  }, childCount: events.length),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The three tiles under the tabs. My Events shows Day Shift / Night Shift
/// / Total Events; Assigned Members shows Total / Day / Night Events.
class _ShiftSummaryRow extends StatelessWidget {
  final _ShiftCounts counts;
  final bool assigned;
  const _ShiftSummaryRow({required this.counts, required this.assigned});

  @override
  Widget build(BuildContext context) {
    final day = DashShiftSummaryCard(
      icon: Icons.wb_sunny_rounded,
      label: assigned ? 'Day Events' : 'Day Shift',
      count: counts.day,
      caption: 'Events with members',
      background: DashColors.dayBg,
      accent: DashColors.gold,
    );
    final night = DashShiftSummaryCard(
      icon: Icons.nightlight_round,
      label: assigned ? 'Night Events' : 'Night Shift',
      count: counts.night,
      caption: 'Events with members',
      background: DashColors.nightBg,
      accent: DashColors.blue,
    );
    final total = DashShiftSummaryCard(
      icon: Icons.groups_rounded,
      label: 'Total Events',
      count: counts.total,
      caption: 'Events with members',
      background: DashColors.dayBg,
      accent: DashColors.gold,
    );
    final tiles = assigned ? [total, day, night] : [day, night, total];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }
}

/// An event on the Assigned Members tab, in the same white-card style as
/// the My Events cards: event name and client, Day / Night badge, location
/// and date, event type and assigned-member count, and a View Details
/// button that opens [_EventMembersScreen] for this event.
class _AssignedEventCard extends StatelessWidget {
  final EventBooking event;
  final VoidCallback onViewDetails;
  const _AssignedEventCard({required this.event, required this.onViewDetails});

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(color: DashColors.textSecondary, fontSize: 13);
    final assigned = event.assignedMembers.length;
    final required = event.requiredMembers;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DashColors.border),
        boxShadow: [
          BoxShadow(
            color: DashColors.navy.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: DashColors.lightGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: DashColors.navy,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.eventName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: DashColors.text,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      event.personName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: muted,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ShiftLabelBadge(shift: event.shift),
            ],
          ),
          const Divider(height: 20, color: DashColors.border),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 15,
                color: DashColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  event.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: muted,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: DashColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(formatEventDate(event.date), style: muted),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (event.eventType.trim().isNotEmpty)
                _InfoPill(
                  icon: Icons.category_outlined,
                  label: event.eventType.trim(),
                ),
              _InfoPill(
                icon: Icons.groups_rounded,
                label: required > 0
                    ? '$assigned / $required members'
                    : '$assigned ${assigned == 1 ? 'member' : 'members'}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: onViewDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: DashColors.navy,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                  side: const BorderSide(color: DashColors.gold, width: 1.2),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View Details',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small light-gray pill with an icon (event type, member count).
class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: DashColors.lightGray,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: DashColors.textSecondary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: DashColors.text,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One event's members, opened from View Details: the event
/// header (with Edit), assigned / present statistics, and each member with
/// present tick, remove, and long-press to call — plus Add Member, which
/// opens the existing allocation picker for this event. Kept live, so
/// changes made here or in the picker show straight away.
class _EventMembersScreen extends StatefulWidget {
  final EventBooking event;
  const _EventMembersScreen({required this.event});

  @override
  State<_EventMembersScreen> createState() => _EventMembersScreenState();
}

class _EventMembersScreenState extends State<_EventMembersScreen> {
  late final Stream<EventBooking?> _event = context
      .read<DataService>()
      .eventBooking(widget.event.id);

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setPresent(
    EventBooking event,
    AssignedMember member,
    bool present,
  ) async {
    try {
      await context.read<DataService>().setMemberPresent(
        event.id,
        member.id,
        present: present,
      );
    } catch (e) {
      _showMessage('Could not update: $e');
    }
  }

  /// Opens the phone dialer for [member]. Assigned members only store an id
  /// and name, so the number is looked up from their login account or, for
  /// a roster-only member, the Admin's Contact list.
  Future<void> _callMember(AssignedMember member) async {
    final auth = context.read<AuthService>();
    final dataService = context.read<DataService>();
    String? phone;
    try {
      final accounts = await auth.members().first;
      phone = accounts.where((u) => u.id == member.id).firstOrNull?.phone;
      if (phone == null || phone.trim().isEmpty) {
        final roster = await dataService.membersOnce();
        phone = roster.where((m) => m.id == member.id).firstOrNull?.phone;
      }
    } catch (e) {
      _showMessage('Could not look up ${member.name}\'s number: $e');
      return;
    }

    if (phone == null || phone.trim().isEmpty) {
      _showMessage('No phone number saved for ${member.name}');
      return;
    }
    final launched = await launchUrl(Uri(scheme: 'tel', path: phone.trim()));
    if (!launched) _showMessage('Could not open the dialer');
  }

  Future<void> _removeMember(EventBooking event, AssignedMember member) async {
    final confirmed = await confirmDelete(context);
    if (!confirmed || !mounted) return;
    try {
      await context.read<DataService>().removeMemberFromEvent(event.id, member);
      _showMessage('${member.name} removed from the event');
    } catch (e) {
      _showMessage('Could not remove: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<EventBooking?>(
      stream: _event,
      initialData: widget.event,
      builder: (context, snapshot) {
        final event = snapshot.data;
        return Scaffold(
          appBar: AppBar(title: const Text('Members')),
          floatingActionButton: event == null
              ? null
              : DashAddEventButton(
                  label: 'Add Member',
                  icon: Icons.person_add_alt_1_rounded,
                  onPressed: () => showAddMembersSheet(context, event),
                ),
          body: SafeArea(
            top: false,
            child: snapshot.hasError
                ? Center(
                    child: Text('Could not load members: ${snapshot.error}'),
                  )
                : event == null
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: DashEmptyCard(
                      icon: Icons.event_busy_rounded,
                      message: 'This event is no longer available.',
                    ),
                  )
                : ResponsiveCenter(
                    maxWidth: 760,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                      children: [
                        DashStaffingEventCard(
                          event: event,
                          onEdit: () =>
                              showEditStaffingEventSheet(context, event),
                          onPresentChanged: (member, present) =>
                              _setPresent(event, member, present),
                          onRemove: (member) => _removeMember(event, member),
                          onCall: _callMember,
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

/// Distinct-event counts behind the Day Shift / Night Shift / Total Events
/// tiles. A booking is one event on one shift, so the same event (same
/// catalog entry and client) booked for both shifts counts towards both
/// shift tiles but only once in [total]. Assigned members never add to it.
class _ShiftCounts {
  final int day;
  final int night;
  final int total;
  const _ShiftCounts(this.day, this.night, this.total);

  factory _ShiftCounts.of(List<EventBooking> events) {
    String key(EventBooking e) {
      final event = e.eventTypeId.isNotEmpty
          ? e.eventTypeId
          : e.eventName.trim().toLowerCase();
      return '$event|${e.personId}';
    }

    final day = {
      for (final e in events)
        if (e.shift == Shift.day) key(e),
    };
    final night = {
      for (final e in events)
        if (e.shift == Shift.night) key(e),
    };
    return _ShiftCounts(day.length, night.length, {...day, ...night}.length);
  }
}

/// A booked-today event card matching the Pending Payments / payments-flow
/// look: person avatar, shift badge, editable Total (amount) & Tips, and
/// Event Done / Cancel Event actions.
class _TodaysEventCard extends StatelessWidget {
  final EventBooking event;
  final ValueChanged<double> onEditTips;
  final ValueChanged<double> onEditAmount;
  final VoidCallback onPaymentDone;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  const _TodaysEventCard({
    required this.event,
    required this.onEditTips,
    required this.onEditAmount,
    required this.onPaymentDone,
    required this.onEdit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(color: DashColors.textSecondary, fontSize: 13);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DashColors.border),
        boxShadow: [
          BoxShadow(
            color: DashColors.navy.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: DashColors.lightGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: DashColors.navy,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.eventName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: DashColors.text,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      event.personName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: muted,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ShiftLabelBadge(shift: event.shift),
              const SizedBox(width: 6),
              Material(
                color: DashColors.navy.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onEdit,
                  child: const Tooltip(
                    message: 'Edit event',
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: DashColors.navy,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20, color: DashColors.border),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 15,
                color: DashColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  event.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: muted,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: DashColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(formatEventDate(event.date), style: muted),
            ],
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _AmountTile(
                    label: 'Total',
                    value: event.amount,
                    background: DashColors.dayBg,
                    borderColor: DashColors.gold.withValues(alpha: 0.6),
                    labelColor: DashColors.goldDeep,
                    valueColor: DashColors.navy,
                    hint: 'double-tap to edit',
                    onDoubleTap: () => _editAmount(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AmountTile(
                    label: 'Tips',
                    value: event.tips,
                    background: DashColors.nightBg,
                    borderColor: DashColors.blue.withValues(alpha: 0.5),
                    labelColor: DashColors.blue,
                    valueColor: DashColors.blue,
                    hint: 'tap to edit',
                    onTap: () => _editTips(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: onPaymentDone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: doneGreen,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    icon: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Event Done',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    icon: const Icon(Icons.cancel_rounded, size: 19),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Cancel Event',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editAmount(BuildContext context) async {
    final value = await promptForAmount(
      context,
      title: 'Amount',
      initial: event.amount,
    );
    if (value != null) onEditAmount(value);
  }

  Future<void> _editTips(BuildContext context) async {
    final value = await promptForAmount(
      context,
      title: 'Tips',
      initial: event.tips,
    );
    if (value != null) onEditTips(value);
  }
}

class _ShiftLabelBadge extends StatelessWidget {
  final Shift shift;
  const _ShiftLabelBadge({required this.shift});

  @override
  Widget build(BuildContext context) {
    final isDay = shift == Shift.day;
    final bg = isDay ? DashColors.dayBadgeBg : DashColors.nightBadgeBg;
    final text = isDay ? DashColors.goldDeep : DashColors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${shift.label} Shift',
        style: TextStyle(
          color: text,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      ),
    );
  }
}

/// Centered "Total" / "Tips" tile on a today's-event card, with a small
/// edit hint. Total edits on double-tap, Tips on a single tap.
class _AmountTile extends StatelessWidget {
  final String label;
  final double value;
  final Color background;
  final Color borderColor;
  final Color labelColor;
  final Color valueColor;
  final String hint;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  const _AmountTile({
    required this.label,
    required this.value,
    required this.background,
    required this.borderColor,
    required this.labelColor,
    required this.valueColor,
    required this.hint,
    this.onTap,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: borderColor),
    );
    return Material(
      color: background,
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatCurrency(value),
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                hint,
                style: TextStyle(
                  color: labelColor.withValues(alpha: 0.6),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleBadgeCard extends StatelessWidget {
  final UserRole role;
  final String email;
  const _RoleBadgeCard({required this.role, required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: role.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(role.icon, color: role.color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role.label,
                  style: TextStyle(
                    color: role.color,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    color: AppColors.textSecondaryLight,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = onSurfaceAccent(context, color);
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black12.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
