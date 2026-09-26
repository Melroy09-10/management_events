import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
      floatingActionButton: DashAddEventButton(
        onPressed: () => Navigator.of(
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
                  : _TodaysEventsBody(isAdmin: role == UserRole.admin),
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
  const _TodaysEventsBody({required this.isAdmin});

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
    if (page != _page) setState(() => _page = page);
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
    final staffingEvents = staffing?.data ?? const <EventBooking>[];
    final showingAssigned = widget.isAdmin && _page == 1;
    final loading = showingAssigned
        ? staffing?.connectionState == ConnectionState.waiting
        : mine.connectionState == ConnectionState.waiting;
    final dayTotal = events.fold<double>(
      0,
      (sum, e) => sum + e.amount + e.tips,
    );

    return ResponsiveCenter(
      maxWidth: 760,
      child: GestureDetector(
        onHorizontalDragEnd: widget.isAdmin ? _onSwipe : null,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              sliver: SliverToBoxAdapter(
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: DashSummaryCard(
                          icon: Icons.calendar_month_rounded,
                          iconColor: DashColors.goldDeep,
                          iconBackground: const Color(0xFFFBF1D5),
                          tint: const Color(0xFFFCF6E6),
                          label: _isToday ? "Today's Events" : 'Events',
                          value: '${events.length}',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PendingEventsScreen(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: DashSummaryCard(
                          icon: Icons.currency_rupee_rounded,
                          iconColor: const Color(0xFF2F6FB5),
                          iconBackground: const Color(0xFFDDEBF9),
                          tint: DashColors.lightBlue,
                          label: _isToday ? "Today's Payments" : 'Payments',
                          value: formatCurrency(dayTotal),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PendingPaymentsScreen(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 26, 16, 14),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        _isToday ? "Today's Events" : 'Events',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: DashColors.textPrimary(context),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    DashCountBadge(
                      count: showingAssigned
                          ? staffingEvents.length
                          : events.length,
                    ),
                    const Spacer(),
                    const SizedBox(width: 8),
                    DashDateSelector(date: _date, onTap: _pickDate),
                  ],
                ),
              ),
            ),
            if (widget.isAdmin)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
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
            if (loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (showingAssigned && staffingEvents.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                sliver: SliverToBoxAdapter(
                  child: DashEmptyCard(
                    icon: Icons.groups_rounded,
                    message: _isToday
                        ? 'No members assigned for today.'
                        : 'No members assigned for this date.',
                  ),
                ),
              )
            else if (showingAssigned)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                sliver: SliverList.separated(
                  itemCount: staffingEvents.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final event = staffingEvents[index];
                    return DashStaffingEventCard(
                      event: event,
                      onEdit: () => showEditStaffingEventSheet(context, event),
                      onPresentChanged: (member, present) =>
                          _setPresent(event, member, present),
                      onRemove: (member) => _removeMember(event, member),
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
                    message: _isToday
                        ? 'No events scheduled for today.'
                        : 'No events scheduled for this date.',
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

/// A booked-today event card matching the Pending Payments / payments-flow
/// look: person avatar, shift badge, editable Total (amount) & Tips, and
/// Event Done / Cancel Event actions.
class _TodaysEventCard extends StatelessWidget {
  final EventBooking event;
  final ValueChanged<double> onEditTips;
  final ValueChanged<double> onEditAmount;
  final VoidCallback onPaymentDone;
  final VoidCallback onCancel;

  const _TodaysEventCard({
    required this.event,
    required this.onEditTips,
    required this.onEditAmount,
    required this.onPaymentDone,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
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
                  Icons.person_rounded,
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
                      event.personName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      event.eventName,
                      style: const TextStyle(
                        color: AppColors.textSecondaryLight,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ShiftLabelBadge(shift: event.shift),
            ],
          ),
          const Divider(height: 26),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 15,
                color: AppColors.textSecondaryLight,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  event.location,
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
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: EditableAmountChip(
                    label: 'Total',
                    value: event.amount,
                    background: amountChipBg,
                    valueColor: paymentOrangeDark,
                    onDoubleTap: () => _editAmount(context),
                  ),
                ),
                const SizedBox(width: 10),
                _TipsButton(tips: event.tips, onTap: () => _editTips(context)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onPaymentDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: doneGreen,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
              label: const Text(
                'Event Done',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text(
                'Cancel Event',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
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
    final bg = shift == Shift.day ? shiftDayBg : shiftNightBg;
    final text = shift == Shift.day ? shiftDayText : shiftNightText;
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

class _TipsButton extends StatelessWidget {
  final double tips;
  final VoidCallback onTap;
  const _TipsButton({required this.tips, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: amountChipBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, size: 16, color: paymentOrangeDark),
              const SizedBox(width: 4),
              Text(
                tips > 0 ? formatCurrency(tips) : 'Tips',
                style: const TextStyle(
                  color: paymentOrangeDark,
                  fontWeight: FontWeight.w800,
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
