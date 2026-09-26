import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/event_booking.dart';
import '../services/data_service.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/history_widgets.dart';
import '../widgets/pending_event_widgets.dart';
import 'add_event_screen.dart';
import '../widgets/app_drawer.dart';

/// All of the current user's own events (not Admin staffing events) that
/// haven't been marked Done yet (any date). Tapping Done here moves an
/// event to Pending Payments.
class PendingEventsScreen extends StatefulWidget {
  const PendingEventsScreen({super.key});

  @override
  State<PendingEventsScreen> createState() => _PendingEventsScreenState();
}

class _PendingEventsScreenState extends State<PendingEventsScreen> {
  static const _maxContentWidth = 760.0;

  /// Ids of events currently animating out after Done / Delete.
  final Set<String> _leaving = {};

  // Created once so setState (exit animations) doesn't hand StreamBuilder a
  // fresh Firestore listener and flash the loading state.
  late final Stream<List<EventBooking>> _pendingStream;

  @override
  void initState() {
    super.initState();
    _pendingStream = context.read<DataService>().pendingPersonalEvents();
  }

  @override
  Widget build(BuildContext context) {
    final dataService = context.read<DataService>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        drawer: const AppDrawer(),
        backgroundColor: HistoryColors.ivory,
        body: StreamBuilder<List<EventBooking>>(
          stream: _pendingStream,
          builder: (context, snapshot) => CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: HistoryHeader(title: 'Pending Events'),
              ),
              ..._buildBody(snapshot, dataService),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 20 + MediaQuery.paddingOf(context).bottom,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBody(
    AsyncSnapshot<List<EventBooking>> snapshot,
    DataService dataService,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: CircularProgressIndicator(color: PendingEventColors.navy),
          ),
        ),
      ];
    }
    if (snapshot.hasError) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: HistoryEmptyState(
              icon: Icons.error_outline_rounded,
              accent: PendingEventColors.danger,
              title: 'Could not load pending events',
              message: '${snapshot.error}',
            ),
          ),
        ),
      ];
    }

    final events = snapshot.data ?? const <EventBooking>[];

    // Forget exit-animation ids once their events have left the stream.
    _leaving.removeWhere((id) => !events.any((e) => e.id == id));

    final dayCount = events.where((e) => e.shift == Shift.day).length;
    final nightCount = events.where((e) => e.shift == Shift.night).length;

    return [
      _boxed(
        HistoryAppear(
          // Same height for all three boxes, even if a label wraps.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: PendingSummaryCard(
                    icon: Icons.calendar_month_rounded,
                    label: 'Total Pending',
                    count: events.length,
                    background: PendingEventColors.navy,
                    iconBackground: PendingEventColors.gold.withValues(
                      alpha: 0.22,
                    ),
                    iconColor: PendingEventColors.gold,
                    foreground: Colors.white,
                    labelColor: Colors.white.withValues(alpha: 0.85),
                    borderColor: PendingEventColors.gold.withValues(
                      alpha: 0.45,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PendingSummaryCard(
                    icon: Icons.wb_sunny_rounded,
                    label: 'Day Events',
                    count: dayCount,
                    background: PendingEventColors.cream,
                    iconBackground: PendingEventColors.gold.withValues(
                      alpha: 0.25,
                    ),
                    iconColor: PendingEventColors.goldDeep,
                    foreground: PendingEventColors.navy,
                    labelColor: PendingEventColors.goldDeep,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PendingSummaryCard(
                    icon: Icons.nightlight_round,
                    label: 'Night Events',
                    count: nightCount,
                    background: PendingEventColors.skyBg,
                    iconBackground: PendingEventColors.sky.withValues(
                      alpha: 0.14,
                    ),
                    iconColor: PendingEventColors.sky,
                    foreground: PendingEventColors.navy,
                    labelColor: PendingEventColors.sky,
                  ),
                ),
              ],
            ),
          ),
        ),
        top: 16,
      ),
      if (events.isEmpty)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: HistoryEmptyState(
              icon: Icons.event_available_rounded,
              title: 'No pending events',
              message:
                  "You're all caught up. New events you add will show here "
                  'until they are marked Done.',
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.only(top: 16),
          sliver: SliverList.builder(
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              return _constrained(
                KeyedSubtree(
                  key: ValueKey('pending-${event.id}'),
                  child: HistoryExit(
                    leaving: _leaving.contains(event.id),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: HistoryAppear(
                        index: index,
                        child: PendingEventCard(
                          event: event,
                          onDone: () => _markDone(event, dataService),
                          onEdit: () => _edit(event),
                          onDelete: () => _delete(event, dataService),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
    ];
  }

  Widget _boxed(Widget child, {double top = 0}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.only(top: top),
        child: _constrained(child),
      ),
    );
  }

  Widget _constrained(Widget child) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: child,
        ),
      ),
    );
  }

  void _edit(EventBooking event) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AddEventScreen(existing: event)));
  }

  Future<void> _markDone(EventBooking event, DataService dataService) {
    return _animateOutThen(
      event.id,
      () => dataService.markBookingDone(event.id),
      successMessage: 'Moved to Pending Payments',
    );
  }

  Future<void> _delete(EventBooking event, DataService dataService) async {
    final confirmed = await confirmDelete(context);
    if (!confirmed || !mounted) return;
    await _animateOutThen(
      event.id,
      () => dataService.deleteEventBooking(event.id),
      successMessage: 'Event deleted',
    );
  }

  /// Plays the card's exit animation, then runs [action]. If it fails the
  /// card is brought back and the error shown.
  Future<void> _animateOutThen(
    String id,
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    if (_leaving.contains(id)) return;
    setState(() => _leaving.add(id));
    await Future<void>.delayed(HistoryExit.duration);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _leaving.remove(id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
    }
  }
}
