import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/event_booking.dart';
import '../services/data_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/payment_chips.dart';

/// Events that have been completed and are awaiting payment collection,
/// grouped by the person who called. Tapping Done settles the payment and
/// moves the event into History.
class PendingPaymentsScreen extends StatelessWidget {
  const PendingPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = context.read<DataService>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        backgroundColor: paymentOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Pending Payments'),
      ),
      body: StreamBuilder<List<EventBooking>>(
        stream: dataService.pendingPayments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load pending payments:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
            );
          }

          final events = snapshot.data ?? const <EventBooking>[];
          if (events.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.payments_outlined, size: 56, color: Colors.black38),
                    const SizedBox(height: 12),
                    Text(
                      'No pending payments',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            );
          }

          final grandTotal = events.fold<double>(0, (sum, e) => sum + e.amount + e.tips);
          final personNames = <String>{for (final e in events) e.personName}.toList()..sort();
          final grouped = <String, List<EventBooking>>{
            for (final name in personNames) name: events.where((e) => e.personName == name).toList(),
          };

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _GrandTotalCard(total: grandTotal, eventCount: events.length, personCount: personNames.length),
              for (final name in personNames) ...[
                const SizedBox(height: 20),
                _PersonHeader(name: name, events: grouped[name]!),
                const SizedBox(height: 12),
                for (final event in grouped[name]!) ...[
                  _PendingPaymentCard(event: event, dataService: dataService),
                  const SizedBox(height: 12),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _GrandTotalCard extends StatelessWidget {
  final double total;
  final int eventCount;
  final int personCount;
  const _GrandTotalCard({required this.total, required this.eventCount, required this.personCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [paymentOrange, paymentOrangeDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: paymentOrangeDark.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 12)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Grand Total Pending', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14)),
                const SizedBox(height: 8),
                Text(
                  formatCurrency(total),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 34),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '$eventCount events',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$personCount ${personCount == 1 ? 'person' : 'persons'}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PersonHeader extends StatelessWidget {
  final String name;
  final List<EventBooking> events;
  const _PersonHeader({required this.name, required this.events});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: paymentOrange.withValues(alpha: 0.16),
            child: Text(initial, style: TextStyle(color: paymentOrangeDark, fontWeight: FontWeight.w800, fontSize: 20)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.black87)),
                const SizedBox(height: 2),
                Text(
                  '${events.length} pending payment${events.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            color: paymentOrange,
            onPressed: () => _copySummary(context, name, events),
          ),
        ],
      ),
    );
  }

  Future<void> _copySummary(BuildContext context, String name, List<EventBooking> events) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Copy Payments'),
        content: const Text('Copy every pending payment for this person, or pick specific events?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('select'),
            child: const Text('Select Events'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop('all'),
            child: const Text('All Events'),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;

    List<EventBooking> chosen;
    if (choice == 'all') {
      chosen = events;
    } else {
      final picked = await _pickEvents(context, events);
      if (picked == null || picked.isEmpty || !context.mounted) return;
      chosen = picked;
    }

    await Clipboard.setData(ClipboardData(text: _buildSummary(name, chosen)));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment summary copied')));
    }
  }

  Future<List<EventBooking>?> _pickEvents(BuildContext context, List<EventBooking> events) {
    final selected = <EventBooking>{};
    return showDialog<List<EventBooking>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select Events'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: events.map((e) {
                return CheckboxListTile(
                  value: selected.contains(e),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(e.eventName),
                  subtitle: Text('${formatEventDate(e.date)} · ${e.shift.label}'),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        selected.add(e);
                      } else {
                        selected.remove(e);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: selected.isEmpty ? null : () => Navigator.of(dialogContext).pop(selected.toList()),
              child: const Text('Copy'),
            ),
          ],
        ),
      ),
    );
  }

  String _buildSummary(String name, List<EventBooking> events) {
    final buffer = StringBuffer('$name Pending Payments\n\n');
    for (final e in events) {
      final shiftEmoji = e.shift == Shift.day ? '☀️' : '🌙';
      buffer.writeln('🍽️ ${e.eventName}');
      buffer.writeln('📅 ${formatEventDate(e.date)}');
      buffer.writeln('$shiftEmoji ${e.shift.label}');
      buffer.writeln('💰 Amount : ${formatCurrency(e.amount)}');
      buffer.writeln('🎁 Tips : ${formatCurrency(e.tips)}');
      buffer.writeln('🧾 Total : ${formatCurrency(e.amount + e.tips)}');
      buffer.writeln();
    }
    return buffer.toString().trimRight();
  }
}

class _PendingPaymentCard extends StatelessWidget {
  final EventBooking event;
  final DataService dataService;
  const _PendingPaymentCard({required this.event, required this.dataService});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  event.eventName,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Colors.black87),
                ),
              ),
              ShiftBadge(shift: event.shift),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 15, color: Colors.black45),
              const SizedBox(width: 6),
              Text(formatEventDate(event.date), style: const TextStyle(color: Colors.black54, fontSize: 13)),
              const SizedBox(width: 16),
              const Icon(Icons.location_on_outlined, size: 15, color: Colors.black45),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  event.location,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: EditableAmountChip(
                  label: 'Amount',
                  value: event.amount,
                  background: amountChipBg,
                  valueColor: Colors.black87,
                  onDoubleTap: () => _editAmount(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: EditableAmountChip(
                  label: 'Tips',
                  value: event.tips,
                  background: tipsChipBg,
                  valueColor: tipsChipText,
                  onDoubleTap: () => _editTips(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: TotalChip(value: event.amount + event.tips)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _markPaid(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: doneGreen,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.check_rounded, color: Colors.white),
                    label: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 52,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => _editTips(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: paymentOrange,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 52,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => _delete(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: deleteChipBg,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Icon(Icons.close_rounded, color: deleteChipIcon),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editAmount(BuildContext context) async {
    final value = await promptForAmount(context, title: 'Amount', initial: event.amount);
    if (value != null) await dataService.updateEventAmount(event.id, value);
  }

  Future<void> _editTips(BuildContext context) async {
    final value = await promptForAmount(context, title: 'Tips', initial: event.tips);
    if (value != null) await dataService.updateEventTips(event.id, value);
  }

  Future<void> _markPaid(BuildContext context) async {
    await dataService.markBookingPaid(event.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as paid — moved to History')));
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await confirmDelete(context);
    if (!confirmed || !context.mounted) return;
    await dataService.deleteEventBooking(event.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event deleted')));
    }
  }
}
