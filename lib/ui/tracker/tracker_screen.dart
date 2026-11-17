import '../../core/localization/strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/models/payment.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/calculator_provider.dart';
import '../../core/providers/tracker_provider.dart';
import 'add_payment_sheet.dart';
import '../calculator/entry_mode_screen.dart';
import '../calculator/one_pager_screen.dart';
import '../home/recycle_bin_screen.dart';

class TrackerScreen extends StatefulWidget {
  final VoidCallback? onOpenMonthly;
  final VoidCallback? onOpenRecords;
  const TrackerScreen({super.key, this.onOpenMonthly, this.onOpenRecords});

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
    final record = calc.defaultRecord(auth.profile?.defaultRecordId);
    if (record == null || !record.isSubmitted) {
      if (tracker.selectedRecord != null) tracker.clearSelection();
    } else if (tracker.selectedRecord?.id != record.id) {
      tracker.selectRecord(auth.user!.uid, record);
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
    final current = calc
        .defaultRecord(context.watch<AuthProvider>().profile?.defaultRecordId);
    if ((current?.isSubmitted == true ? current?.id : null) !=
        tracker.selectedRecord?.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _autoSelect();
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l(context, "Zakat Tracker")),
        actions: [
          if (tracker.selectedRecord != null &&
              submitted.any((r) => r.id == tracker.selectedRecord!.id))
            IconButton(
                tooltip: l(context, "Move record to recycle bin"),
                icon: const Icon(Icons.delete_outline),
                onPressed: () =>
                    moveToRecycleBin(context, tracker.selectedRecord!)),
          IconButton(
              icon: const Icon(Icons.folder_open_outlined),
              tooltip: l(context, "Records in Home"),
              onPressed: widget.onOpenRecords),
        ],
      ),
      body: calc.recordsLoading && tracker.selectedRecord == null
          ? const Center(child: CircularProgressIndicator())
          : tracker.selectedRecord == null
              ? _EmptyState(
                  draftName: current?.name,
                  onSetup: () {
                    if (current != null && !current.isSubmitted) {
                      calc.resumeRecord(current);
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const OnePagerScreen()));
                    } else {
                      Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const EntryModeScreen()));
                    }
                  })
              : Column(
                  children: [
                    if (tracker.error != null)
                      TextButton(
                          onPressed: tracker.reload,
                          child: Text(
                              l(context, "{0} Tap to retry.", [tracker.error!]),
                              style: const TextStyle(color: Colors.red))),
                    if (tracker.selectedRecord!.currency == null)
                      Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(l(context,
                              "This older record has no saved currency. Amounts are shown without a currency; adding payments is disabled."))),
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

  Future<void> _confirmDelete(
      BuildContext ctx, Payment p, String uid, TrackerProvider tracker) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(l(context, "Delete Payment")),
        content: Text(
            l(context, "Delete \"{0}\"? This cannot be undone.", [p.name])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l(context, "Cancel"))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l(context, "Delete")),
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
                      ? l(context, "Hawl complete")
                      : l(context, "{0} days left", [r.daysLeftInHawl]),
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
              _StatColumn(
                  label: l(context, "Paid"),
                  value: fmt.format(tracker.totalPaid)),
              _StatColumn(
                  label: r.hawlComplete
                      ? l(context, "Due")
                      : l(context, "Estimate"),
                  value: fmt.format(tracker.totalDue)),
              _StatColumn(
                  label: l(context, "Remaining"),
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
            l(context, "{0}% paid", [(pct * 100).toStringAsFixed(0)]),
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
        Text(l(context, label),
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          l(context, value),
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
          hintText: l(context, "Search payments..."),
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
            Text(
                searching
                    ? l(context, "No matching payments")
                    : l(context, "No payments yet"),
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
                searching
                    ? l(context, "Try a different name or recipient.")
                    : l(context, "Tap + to record a payment"),
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
                          ? l(context, "Payment")
                          : p.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                p.isMonthly
                    ? l(context, "{0}\nPaid {1} · Managed in {2}", [
                        monthlyLabel,
                        dateFmt.format(p.date),
                        context
                                .watch<AuthProvider>()
                                .profile
                                ?.monthlyGivingLabel ??
                            'Monthly Giving'
                      ])
                    : '${dateFmt.format(p.date)}${p.recipient.isNotEmpty ? ' · ${p.recipient}' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l(context, fmt.format(p.amount)),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: kPrimaryGreen,
                          fontSize: 14)),
                  const SizedBox(width: 4),
                  if (p.isMonthly)
                    IconButton(
                        tooltip: l(context, "Manage in {0}", [
                          context
                                  .watch<AuthProvider>()
                                  .profile
                                  ?.monthlyGivingLabel ??
                              'Monthly Giving'
                        ]),
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
                      itemBuilder: (_) => [
                        PopupMenuItem(
                            value: 'edit', child: Text(l(context, "Edit"))),
                        PopupMenuItem(
                            value: 'delete',
                            child: Text(l(context, "Delete"),
                                style: const TextStyle(color: Colors.red))),
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
  final String? draftName;
  const _EmptyState({required this.onSetup, this.draftName});

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
            Text(
                draftName == null
                    ? l(context, "No Zakat record yet")
                    : l(context, "Finalize your default record"),
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            const SizedBox(height: 8),
            Text(
              draftName == null
                  ? l(context,
                      "Complete a Zakat calculation first to start tracking payments.")
                  : l(
                      context,
                      "{0} is a draft. Submit it before tracking payments.",
                      [draftName]),
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onSetup,
              child: Text(draftName == null
                  ? l(context, "Start a calculation")
                  : l(context, "Finish this calculation")),
            ),
          ],
        ),
      ),
    );
  }
}
