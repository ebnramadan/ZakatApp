import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/models/payment.dart';
import '../../core/models/zakat_record.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/calculator_provider.dart';
import '../../core/providers/tracker_provider.dart';
import 'add_payment_sheet.dart';
import '../calculator/entry_mode_screen.dart';
import '../home/recycle_bin_screen.dart';

class TrackerScreen extends StatefulWidget {
  final VoidCallback? onOpenMonthly;
  const TrackerScreen({super.key, this.onOpenMonthly});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _autoSelect();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _autoSelect() {
    final auth = context.read<AuthProvider>();
    final calc = context.read<CalculatorProvider>();
    final tracker = context.read<TrackerProvider>();
    final submitted = calc.records.where((r) => r.isSubmitted).toList();
    if (tracker.selectedRecord != null &&
        !submitted.any((r) => r.id == tracker.selectedRecord!.id)) {
      tracker.clearSelection();
    }
    if (submitted.isNotEmpty && tracker.selectedRecord == null) {
      tracker.selectRecord(auth.user!.uid, submitted.first);
    }
  }

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const AddPaymentSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final calc = context.watch<CalculatorProvider>();
    final tracker = context.watch<TrackerProvider>();
    final currency = tracker.selectedRecord?.currency;
    final submitted = calc.records.where((r) => r.isSubmitted).toList();
    if ((tracker.selectedRecord == null && submitted.isNotEmpty) ||
        (tracker.selectedRecord != null &&
            !submitted.any((r) => r.id == tracker.selectedRecord!.id))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _autoSelect();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zakat Tracker'),
        actions: [
          if (tracker.selectedRecord != null &&
              submitted.any((r) => r.id == tracker.selectedRecord!.id))
            IconButton(
                tooltip: 'Move record to recycle bin',
                icon: const Icon(Icons.delete_outline),
                onPressed: () =>
                    moveToRecycleBin(context, tracker.selectedRecord!)),
          if (submitted.length > 1)
            IconButton(
              icon: const Icon(Icons.swap_vert),
              tooltip: 'Switch record',
              onPressed: () =>
                  _showRecordPicker(context, submitted, auth.user!.uid),
            ),
        ],
      ),
      body: calc.recordsLoading && tracker.selectedRecord == null
          ? const Center(child: CircularProgressIndicator())
          : tracker.selectedRecord == null
              ? _EmptyState(onSetup: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const EntryModeScreen()));
                })
              : Column(
                  children: [
                    if (tracker.error != null)
                      TextButton(
                          onPressed: tracker.reload,
                          child: Text('${tracker.error!} Tap to retry.',
                              style: const TextStyle(color: Colors.red))),
                    if (tracker.selectedRecord!.currency == null)
                      const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                              'This older record has no saved currency. Amounts are shown without a currency; adding payments is disabled.')),
                    _Header(tracker: tracker, currency: currency),
                    const Divider(height: 1),
                    _SearchBar(
                      controller: _searchCtrl,
                      onChanged: (q) => setState(() => _query = q),
                    ),
                    Expanded(
                      child: _PaymentList(
                        payments: tracker.search(_query),
                        searching: _query.trim().isNotEmpty,
                        onOpenMonthly: widget.onOpenMonthly,
                        currency: currency,
                        onEdit: (p) => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(20))),
                          builder: (_) => AddPaymentSheet(existing: p),
                        ),
                        onDelete: (p) =>
                            _confirmDelete(context, p, auth.user!.uid, tracker),
                      ),
                    ),
                  ],
                ),
      floatingActionButton: tracker.selectedRecord?.currency != null
          ? FloatingActionButton(
              heroTag: 'add-payment',
              onPressed: _openAddSheet,
              child: const Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _showRecordPicker(
      BuildContext ctx, List<ZakatRecord> records, String uid) {
    final tracker = ctx.read<TrackerProvider>();
    showModalBottomSheet(
      context: ctx,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Select Zakat Record',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...records.map((r) => ListTile(
                title: Text(r.name),
                subtitle:
                    Text(DateFormat('d MMM yyyy').format(r.hawlStartDate)),
                trailing: tracker.selectedRecord?.id == r.id
                    ? const Icon(Icons.check, color: kPrimaryGreen)
                    : null,
                onTap: () {
                  tracker.selectRecord(uid, r);
                  Navigator.of(ctx).pop();
                },
              )),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext ctx, Payment p, String uid, TrackerProvider tracker) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Delete Payment'),
        content: Text('Delete "${p.name}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await tracker.deletePayment(uid, p.id);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header with summary stats
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final TrackerProvider tracker;
  final String? currency;

  const _Header({required this.tracker, required this.currency});

  @override
  Widget build(BuildContext context) {
    final fmt = currency == null
        ? NumberFormat('#,##0.00')
        : NumberFormat.currency(
            name: currency,
            symbol: currencySymbol(currency!),
            decimalDigits: currencyDecimals(currency!));
    final r = tracker.selectedRecord!;
    final pct = tracker.totalDue > 0
        ? (tracker.totalPaid / tracker.totalDue).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      color: kPrimaryGreen,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(r.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold))),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  r.hawlComplete
                      ? 'Hawl complete'
                      : '${r.daysLeftInHawl} days left',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              _StatColumn(label: 'Paid', value: fmt.format(tracker.totalPaid)),
              _StatColumn(
                  label: r.hawlComplete ? 'Due' : 'Estimate',
                  value: fmt.format(tracker.totalDue)),
              _StatColumn(
                  label: 'Remaining',
                  value: fmt.format(tracker.remaining),
                  highlight: tracker.remaining == 0),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.white30,
              valueColor: const AlwaysStoppedAnimation<Color>(kGold),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(pct * 100).toStringAsFixed(0)}% paid',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _StatColumn(
      {required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
              color: highlight ? kGold : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search bar
// ─────────────────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String) onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search payments...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Payment list
// ─────────────────────────────────────────────────────────────────────────────
class _PaymentList extends StatelessWidget {
  final List<Payment> payments;
  final bool searching;
  final VoidCallback? onOpenMonthly;
  final String? currency;
  final void Function(Payment) onEdit;
  final void Function(Payment) onDelete;

  const _PaymentList({
    required this.payments,
    this.searching = false,
    this.onOpenMonthly,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                searching
                    ? Icons.search_off
                    : Icons.volunteer_activism_outlined,
                size: 48,
                color: Colors.grey),
            const SizedBox(height: 12),
            Text(searching ? 'No matching payments' : 'No payments yet',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
                searching
                    ? 'Try a different name or recipient.'
                    : 'Tap + to record a payment',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    final fmt = currency == null
        ? NumberFormat('#,##0.00')
        : NumberFormat.currency(
            name: currency,
            symbol: currencySymbol(currency!),
            decimalDigits: currencyDecimals(currency!));
    final dateFmt = DateFormat('d MMM yyyy');

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: payments.length,
      itemBuilder: (ctx, i) {
        final p = payments[i];
        final month = p.monthlyPaymentId?.split('_').last;
        final period = month == null ? null : DateTime.tryParse('$month-01');
        final monthlyLabel = period == null
            ? 'Monthly giving'
            : DateFormat.yMMMM().format(period);
        return Dismissible(
          key: Key(p.id),
          direction:
              p.isMonthly ? DismissDirection.none : DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) async {
            onDelete(p);
            return false;
          },
          child: Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: kGold.withOpacity(0.15),
                child: const Icon(Icons.volunteer_activism,
                    color: kGold, size: 20),
              ),
              title: Text(
                  p.isMonthly
                      ? p.recipient
                      : p.name.isEmpty
                          ? 'Payment'
                          : p.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                p.isMonthly
                    ? '$monthlyLabel\nPaid ${dateFmt.format(p.date)} · Managed in ${context.watch<AuthProvider>().profile?.monthlyGivingLabel ?? 'Monthly Giving'}'
                    : '${dateFmt.format(p.date)}${p.recipient.isNotEmpty ? ' · ${p.recipient}' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(fmt.format(p.amount),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: kPrimaryGreen,
                          fontSize: 14)),
                  const SizedBox(width: 4),
                  if (p.isMonthly)
                    IconButton(
                        tooltip:
                            'Manage in ${context.watch<AuthProvider>().profile?.monthlyGivingLabel ?? 'Monthly Giving'}',
                        onPressed: onOpenMonthly,
                        icon:
                            const Icon(Icons.calendar_month_outlined, size: 20))
                  else
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert,
                          size: 18, color: Colors.grey),
                      onSelected: (v) {
                        if (v == 'edit') onEdit(p);
                        if (v == 'delete') onDelete(p);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete',
                                style: TextStyle(color: Colors.red))),
                      ],
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

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onSetup;
  const _EmptyState({required this.onSetup});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calculate_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No Zakat record yet',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            const SizedBox(height: 8),
            const Text(
              'Complete a Zakat calculation first to start tracking payments.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onSetup,
              child: const Text('Go to Calculator'),
            ),
          ],
        ),
      ),
    );
  }
}
