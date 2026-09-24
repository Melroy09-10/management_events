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
      appBar: AppBar(title: const Text('Dashboard')),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: paymentOrange,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AddEventScreen())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Event'),
      ),
      body: SafeArea(
        child: role == UserRole.superAdmin
            ? _SuperAdminDashboardBody(user: user, quickActions: _quickActions)
            : _TodaysEventsBody(isAdmin: role == UserRole.admin),
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

/// Shown only to Admin & User: today's events booked on the current
/// user's own account (Add Event → event_bookings).
///
/// For an Admin, the list below the header swipes between two pages: their
/// own events for today, and everyone assigned to today's staffing events.
class _TodaysEventsBody extends StatefulWidget {
  final bool isAdmin;
  const _TodaysEventsBody({required this.isAdmin});

  @override
  State<_TodaysEventsBody> createState() => _TodaysEventsBodyState();
}

class _TodaysEventsBodyState extends State<_TodaysEventsBody> {
  // Created once so switching pages doesn't resubscribe and flash loading.
  late final Stream<List<EventBooking>> _myEvents;
  late final Stream<List<EventBooking>> _staffingEvents;

  /// 0 = My Events, 1 = Assigned Members (Admin only).
  int _page = 0;

  @override
  void initState() {
    super.initState();
    final dataService = context.read<DataService>();
    final today = DateTime.now();
    _myEvents = dataService.eventBookingsForDate(today);
    _staffingEvents = dataService.staffingEventsForDate(today);
  }

  void _goTo(int page) {
    if (page != _page) setState(() => _page = page);
  }

  void _onSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -250) _goTo(1);
    if (velocity > 250) _goTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final dataService = context.read<DataService>();

    return StreamBuilder<List<EventBooking>>(
      stream: _myEvents,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final events = snapshot.data ?? const <EventBooking>[];

        return ResponsiveCenter(
          maxWidth: 760,
          child: GestureDetector(
            onHorizontalDragEnd: widget.isAdmin ? _onSwipe : null,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: _PendingAmountCard(dataService: dataService),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: _TodayStatsRow(events: events),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Row(
                      children: [
                        Text(
                          "Today's Events",
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: paymentOrange.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${events.length}',
                            style: const TextStyle(
                              color: paymentOrangeDark,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.isAdmin)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: _TodayPageSwitcher(page: _page, onChanged: _goTo),
                    ),
                  ),
                if (widget.isAdmin && _page == 1)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverToBoxAdapter(
                      child: _TodaysAssignedMembers(stream: _staffingEvents),
                    ),
                  )
                else if (loading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (events.isEmpty)
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(20, 0, 20, 100),
                    sliver: SliverToBoxAdapter(child: _NoTodaysEventsCard()),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
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
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Moved to Pending Payments'),
                                  ),
                                );
                              }
                            },
                            onCancel: () async {
                              final confirmed = await confirmDelete(context);
                              if (!confirmed || !context.mounted) return;
                              await dataService.deleteEventBooking(event.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Event cancelled'),
                                  ),
                                );
                              }
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
      },
    );
  }
}

/// Two-option pill ("My Events" / "Assigned Members") above the Admin's
/// Today's Events list. Swiping the list sideways switches it too.
class _TodayPageSwitcher extends StatelessWidget {
  final int page;
  final ValueChanged<int> onChanged;
  const _TodayPageSwitcher({required this.page, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: paymentOrange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              _option(0, Icons.event_rounded, 'My Events'),
              _option(1, Icons.groups_rounded, 'Assigned Members'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 2; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: page == i ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: page == i
                      ? paymentOrange
                      : paymentOrange.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _option(int index, IconData icon, String label) {
    final selected = page == index;
    final color = selected ? Colors.white : paymentOrangeDark;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? paymentOrange : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Admin's second Today's Events page: each of today's staffing events with
/// the members assigned to it.
class _TodaysAssignedMembers extends StatelessWidget {
  final Stream<List<EventBooking>> stream;
  const _TodaysAssignedMembers({required this.stream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EventBooking>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final events = snapshot.data ?? const <EventBooking>[];
        if (events.isEmpty) return const _EmptyAssignedCard();

        final total = events.fold<int>(
          0,
          (sum, e) => sum + e.assignedMembers.length,
        );
        final noun = total == 1 ? 'member' : 'members';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                '$total $noun working today',
                style: TextStyle(
                  color: AppColors.textSecondaryLight,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
            for (final event in events) ...[
              _AssignedEventCard(event: event),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

/// One of today's staffing events: name, date, shift, how many are assigned
/// out of how many are needed, and the assigned members A–Z — each with a
/// "present" tick (attendance only) and a remove button.
class _AssignedEventCard extends StatelessWidget {
  final EventBooking event;
  const _AssignedEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final assigned = event.assignedMembers.length;
    final present = event.assignedMembers
        .where((m) => event.presentMemberIds.contains(m.id))
        .length;
    final isFull = assigned >= event.requiredMembers;
    final countColor = isFull ? AppColors.success : AppColors.goldDark;
    final members = [...event.assignedMembers]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                        fontSize: 15.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        ShiftBadge(shift: event.shift),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: AppColors.textSecondaryLight,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            formatEventDate(event.date),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondaryLight,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _CardIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Edit event',
                background: paymentOrange.withValues(alpha: 0.1),
                color: onSurfaceAccent(context, paymentOrange),
                onPressed: () => showEditStaffingEventSheet(context, event),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.groups_rounded, size: 16, color: countColor),
              const SizedBox(width: 6),
              Text(
                '$assigned of ${event.requiredMembers} assigned',
                style: TextStyle(
                  color: countColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              const Spacer(),
              if (assigned > 0)
                Text(
                  '$present present',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
            ],
          ),
          const Divider(height: 22),
          if (members.isEmpty)
            Text(
              'No members assigned yet',
              style: TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            for (final member in members)
              _AssignedMemberRow(
                event: event,
                member: member,
                present: event.presentMemberIds.contains(member.id),
              ),
        ],
      ),
    );
  }
}

/// A member on an [_AssignedEventCard]: present tick, name, remove button.
class _AssignedMemberRow extends StatelessWidget {
  final EventBooking event;
  final AssignedMember member;
  final bool present;
  const _AssignedMemberRow({
    required this.event,
    required this.member,
    required this.present,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Checkbox(
            value: present,
            activeColor: AppColors.success,
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            onChanged: (value) => _setPresent(context, value ?? false),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () => _setPresent(context, !present),
              child: Text(
                member.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: present ? AppColors.success : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _CardIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Remove from event',
            size: 30,
            iconSize: 16,
            background: deleteChipBg,
            color: deleteChipIcon,
            onPressed: () => _remove(context),
          ),
        ],
      ),
    );
  }

  Future<void> _setPresent(BuildContext context, bool value) async {
    try {
      await context.read<DataService>().setMemberPresent(
        event.id,
        member.id,
        present: value,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not update: $e')));
      }
    }
  }

  Future<void> _remove(BuildContext context) async {
    final confirmed = await confirmDelete(context);
    if (!confirmed || !context.mounted) return;
    try {
      await context.read<DataService>().removeMemberFromEvent(event.id, member);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member.name} removed from the event')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not remove: $e')));
      }
    }
  }
}

/// Small round icon button used on the Assigned Members cards.
class _CardIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color background;
  final Color color;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;
  const _CardIconButton({
    required this.icon,
    required this.tooltip,
    required this.background,
    required this.color,
    required this.onPressed,
    this.size = 36,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          color: background,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Icon(icon, size: iconSize, color: color),
          ),
        ),
      ),
    );
  }
}

class _EmptyAssignedCard extends StatelessWidget {
  const _EmptyAssignedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Icons.groups_rounded,
              color: AppColors.secondary,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No members assigned for today.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

/// Orange hero card showing the signed-in user's total pending payment
/// amount across all their pendingPayment-status bookings. Tapping it opens
/// the Pending Payments screen.
class _PendingAmountCard extends StatelessWidget {
  final DataService dataService;
  const _PendingAmountCard({required this.dataService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EventBooking>>(
      stream: dataService.pendingPayments(),
      builder: (context, snapshot) {
        final events = snapshot.data ?? const <EventBooking>[];
        final total = events.fold<double>(
          0,
          (sum, e) => sum + e.amount + e.tips,
        );

        return GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PendingPaymentsScreen()),
          ),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [paymentOrange, paymentOrangeDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: paymentOrangeDark.withValues(alpha: 0.35),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Pending Amount',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${events.length} event${events.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  formatCurrency(total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 30,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap to view all pending payments',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Two compact stat tiles for today only: how many events are booked today,
/// and the total payment (amount + tips) across just those today's events —
/// distinct from the Pending Amount card above, which covers every pending
/// payment regardless of date.
class _TodayStatsRow extends StatelessWidget {
  final List<EventBooking> events;
  const _TodayStatsRow({required this.events});

  @override
  Widget build(BuildContext context) {
    final todayTotal = events.fold<double>(
      0,
      (sum, e) => sum + e.amount + e.tips,
    );
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.event_note_rounded,
            label: "Today's Events",
            value: '${events.length}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            icon: Icons.currency_rupee_rounded,
            label: "Today's Payment",
            value: formatCurrency(todayTotal),
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: AppColors.goldDark, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondaryLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimaryLight,
              fontWeight: FontWeight.w800,
              fontSize: 19,
            ),
          ),
        ],
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

class _NoTodaysEventsCard extends StatelessWidget {
  const _NoTodaysEventsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Icons.event_available_rounded,
              color: AppColors.secondary,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No events scheduled for today.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ],
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
