import '../../core/localization/amount_formatter.dart';
import '../../core/localization/strings.dart';
import '../shared/giving_celebration.dart';
import '../widgets/searchable_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants.dart';
import '../../core/models/monthly_giving.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/calculator_provider.dart';
import '../../core/providers/monthly_provider.dart';

class MonthlyScreen extends StatefulWidget {
  final String? focusRecipient;
  const MonthlyScreen({super.key, this.focusRecipient});
  @override
  State<MonthlyScreen> createState() => _MonthlyScreenState();
}

class _MonthlyScreenState extends State<MonthlyScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  String _query = '';
  late final TextEditingController _search;
  bool _followingCurrent = true;
  bool _showPaused = false;
  @override
  void initState() {
    super.initState();
    _query = widget.focusRecipient ?? '';
    _search = TextEditingController(text: _query);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _shift(int by) => setState(() {
        _followingCurrent = false;
        _month = DateTime(_month.year, _month.month + by);
      });
  void _currentMonth() => setState(() {
        _followingCurrent = true;
        _month = DateTime(DateTime.now().year, DateTime.now().month);
      });
  Future<void> _edit({MonthlyPlan? plan}) async {
    await showDialog<void>(
        context: context,
        builder: (_) =>
            MonthlyPlanDialog(existing: plan, initialMonth: _month));
  }

  Future<void> _undo(MonthlyPayment payment) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(l(context, "Undo this payment?")),
                content:
                    Text(l(context, "This marks {0} as unpaid for {1}.{2}", [
                  payment.recipient,
                  DateFormat.yMMMM().format(monthFromKey(payment.month)),
                  payment.kind == 'zakat'
                      ? l(context,
                          " The matching Zakat tracker entry will also be removed.")
                      : ''
                ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(l(context, "Keep payment"))),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(l(context, "Undo payment")))
                ]));
    if (!mounted || confirmed != true) return;
    final monthly = context.read<MonthlyProvider>();
    final ok = await monthly.undo(payment);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? l(context, "Payment undone.")
              : l(context, monthly.error!))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthly = context.watch<MonthlyProvider>();
    final auth = context.watch<AuthProvider>();
    if (_followingCurrent) {
      _month = DateTime(DateTime.now().year, DateTime.now().month);
    }
    final key = monthKey(_month);
    final nowKey = monthKey(DateTime.now());
    final all = monthly.plans
        .where((p) =>
            ((p.active || _showPaused) && p.startMonth.compareTo(key) <= 0) ||
            monthly.paid(p.id, key) != null)
        .toList();
    final shown = all
        .where((p) => p.recipient.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    final calc = context.watch<CalculatorProvider>();
    bool available(String kind, String id) =>
        kind != 'zakat' || calc.isRecordActive(id);
    final paid = monthly.forMonth(key);
    final currencies = {
      ...all.map((p) => p.currency),
      ...paid.map((p) => p.currency)
    }.toList()
      ..sort();
    return Scaffold(
      appBar: AppBar(
          title: Text(l(
              context,
              context.watch<AuthProvider>().profile?.monthlyGivingLabel ??
                  'Monthly Giving')),
          actions: [
            IconButton(
                tooltip: l(context, "Monthly giving settings"),
                onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const MonthlySettings()),
                icon: const Icon(Icons.tune))
          ]),
      body: monthly.loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => monthly.load(auth.user!.uid, force: true),
              child: ListView(
                  key: const Key('monthly-list'),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
                  children: [
                    Text(l(context, "A little, every month."),
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                        l(context,
                            "Keep your monthly commitments in one place. Mark a payment only after you have given the money."),
                        style: const TextStyle(
                            height: 1.6, color: Colors.black54)),
                    const SizedBox(height: 18),
                    Row(children: [
                      IconButton(
                          tooltip: l(context, "Previous month"),
                          onPressed: () => _shift(-1),
                          icon: Icon(
                              Directionality.of(context) == TextDirection.rtl
                                  ? Icons.chevron_right
                                  : Icons.chevron_left)),
                      Expanded(
                          child: Text(
                              l(context, DateFormat.yMMMM().format(_month)),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge)),
                      IconButton(
                          tooltip: l(context, "Next month"),
                          onPressed: () => _shift(1),
                          icon: Icon(
                              Directionality.of(context) == TextDirection.rtl
                                  ? Icons.chevron_left
                                  : Icons.chevron_right))
                    ]),
                    if (key != nowKey)
                      Center(
                          child: TextButton(
                              onPressed: _currentMonth,
                              child: Text(l(context, "Back to this month")))),
                    if (key.compareTo(nowKey) > 0)
                      Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(l(context,
                              "Planning ahead. Future months cannot be marked paid yet."))),
                    if (monthly.error != null)
                      Card(
                          child: ListTile(
                              leading: const Icon(Icons.error_outline),
                              title: Text(l(context, monthly.error!)),
                              trailing: TextButton(
                                  onPressed: () =>
                                      monthly.load(auth.user!.uid, force: true),
                                  child: Text(l(context, "Retry"))))),
                    ...currencies.map((currency) {
                      final paidTotal = paid
                          .where((p) => p.currency == currency)
                          .fold(0.0, (s, p) => s + p.amount);
                      final outstanding = all
                          .where((p) =>
                              p.active &&
                              p.currency == currency &&
                              available(p.kind, p.zakatRecordId) &&
                              monthly.paid(p.id, key) == null)
                          .fold(0.0, (s, p) => s + p.amount);
                      final fmt = NumberFormat.currency(
                          name: currency, symbol: '$currency ');
                      return Card(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: Padding(
                              padding: const EdgeInsets.all(18),
                              child:
                                  Wrap(spacing: 28, runSpacing: 12, children: [
                                _MonthlyStat(
                                    l(context, "Planned this month"),
                                    fmt.format(all
                                        .where((p) =>
                                            p.active &&
                                            p.currency == currency &&
                                            available(p.kind, p.zakatRecordId))
                                        .fold(0.0, (s, p) => s + p.amount))),
                                _MonthlyStat(l(context, "Given this month"),
                                    fmt.format(paidTotal)),
                                _MonthlyStat(l(context, "Still to give"),
                                    fmt.format(outstanding)),
                              ])));
                    }),
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, children: [
                      FilterChip(
                          label: Text(l(context, "Include paused recipients")),
                          selected: _showPaused,
                          onSelected: (value) =>
                              setState(() => _showPaused = value)),
                    ]),
                    const SizedBox(height: 12),
                    if (_query.isNotEmpty)
                      Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: InputChip(
                              label: Text(l(context, "Showing: {0}", [_query])),
                              onDeleted: () {
                                _search.clear();
                                setState(() => _query = '');
                              })),
                    if (all.isNotEmpty)
                      TextField(
                          controller: _search,
                          decoration: InputDecoration(
                              labelText: l(context, "Find a recipient"),
                              prefixIcon: const Icon(Icons.search)),
                          onChanged: (v) => setState(() => _query = v)),
                    const SizedBox(height: 12),
                    if (all.isEmpty)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          child: Column(children: [
                            Icon(Icons.volunteer_activism_outlined,
                                size: 58,
                                color: Theme.of(context).colorScheme.primary),
                            const SizedBox(height: 16),
                            Text(l(context, "Start a monthly habit"),
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 8),
                            Text(
                                l(context,
                                    "Add a person and an amount. Choose صدقة or connect a Zakat record, then record each month when you pay."),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    height: 1.6, color: Colors.black54)),
                            const SizedBox(height: 20),
                            OutlinedButton.icon(
                                onPressed: () => _edit(),
                                icon: const Icon(Icons.add),
                                label: Text(
                                    l(context, "Add your first recipient")))
                          ])),
                    if (all.isNotEmpty && shown.isEmpty)
                      Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                              l(context, "No recipients match your search."))),
                    ...shown.map((plan) {
                      final receipt = monthly.paid(plan.id, key);
                      final isPaid = receipt != null;
                      final blocked = !available(receipt?.kind ?? plan.kind,
                          receipt?.zakatRecordId ?? plan.zakatRecordId);
                      final kind = receipt?.kind ?? plan.kind;
                      final amount = receipt?.amount ?? plan.amount;
                      final due = plan.dueDate(key);
                      final overdue = !isPaid && !due.isAfter(DateTime.now());
                      return Card(
                          child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                              backgroundColor: isPaid
                                                  ? Colors.green.shade50
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .primaryContainer,
                                              child: Icon(
                                                  isPaid
                                                      ? Icons.check
                                                      : Icons.person_outline,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary)),
                                          const SizedBox(width: 12),
                                          Expanded(
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                Text(
                                                    l(
                                                        context,
                                                        receipt?.recipient ??
                                                            plan.recipient),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium
                                                        ?.copyWith(
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                const SizedBox(height: 4),
                                                Text(
                                                    kind == 'zakat'
                                                        ? l(context,
                                                            "زكاة · Counts toward your selected Zakat record")
                                                        : l(context,
                                                            "صدقة · Separate from Zakat"),
                                                    style: const TextStyle(
                                                        fontSize: 12,
                                                        height: 1.5))
                                              ])),
                                          PopupMenuButton<String>(
                                              tooltip: l(
                                                  context, "Manage recipient"),
                                              onSelected: (v) async {
                                                if (v == 'edit') {
                                                  _edit(plan: plan);
                                                }
                                                if (v == 'pause') {
                                                  final pause = await showDialog<
                                                          bool>(
                                                      context: context,
                                                      builder: (ctx) =>
                                                          AlertDialog(
                                                              title: Text(l(
                                                                  context,
                                                                  "Pause monthly giving?")),
                                                              content: Text(l(
                                                                  context,
                                                                  "Stop future commitments and reminders for {0}. Payments already recorded will remain in your history.",
                                                                  [
                                                                    plan.recipient
                                                                  ])),
                                                              actions: [
                                                                TextButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                            ctx,
                                                                            false),
                                                                    child: Text(l(
                                                                        context,
                                                                        "Cancel"))),
                                                                TextButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                            ctx,
                                                                            true),
                                                                    child: Text(l(
                                                                        context,
                                                                        "Pause recipient")))
                                                              ]));
                                                  if (pause == true) {
                                                    await monthly
                                                        .save(plan.archived());
                                                  }
                                                }
                                              },
                                              itemBuilder: (_) => [
                                                    PopupMenuItem(
                                                        value: 'edit',
                                                        child: Text(l(context,
                                                            "Edit commitment"))),
                                                    if (plan.active)
                                                      PopupMenuItem(
                                                          value: 'pause',
                                                          child: Text(l(context,
                                                              "Pause recipient")))
                                                  ])
                                        ]),
                                    const SizedBox(height: 16),
                                    Text(
                                        l(
                                            context,
                                            NumberFormat.currency(
                                                    name: receipt?.currency ??
                                                        plan.currency,
                                                    symbol:
                                                        '${receipt?.currency ?? plan.currency} ')
                                                .format(amount)),
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Text(
                                        isPaid
                                            ? l(context, "Paid on {0}", [
                                                DateFormat.yMMMd()
                                                    .format(receipt.paidAt)
                                              ])
                                            : '${overdue ? 'Ready to give' : 'Reminder'} · ${DateFormat.MMMd().format(due)}',
                                        style: TextStyle(
                                            color: isPaid
                                                ? Colors.green.shade800
                                                : overdue
                                                    ? Colors.deepOrange.shade800
                                                    : Colors.black54)),
                                    const SizedBox(height: 14),
                                    if (blocked)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 12),
                                          child: Text(l(context,
                                              "Linked Zakat record is unavailable. Restore it from the recycle bin or edit this commitment to select another record."))),
                                    if (isPaid)
                                      TextButton.icon(
                                          onPressed: monthly.busy || blocked
                                              ? null
                                              : () => _undo(receipt),
                                          icon:
                                              const Icon(Icons.undo, size: 18),
                                          label:
                                              Text(l(context, "Undo payment")))
                                    else
                                      OutlinedButton.icon(
                                          onPressed: monthly.busy ||
                                                  blocked ||
                                                  key.compareTo(nowKey) > 0
                                              ? null
                                              : () async {
                                                  FocusManager
                                                      .instance.primaryFocus
                                                      ?.unfocus();
                                                  final today = DateTime.now();
                                                  final end = DateTime(
                                                      _month.year,
                                                      _month.month + 1,
                                                      0);
                                                  final latest =
                                                      end.isBefore(today)
                                                          ? end
                                                          : today;
                                                  DateTime? paidOn = today;
                                                  if (key != nowKey) {
                                                    paidOn = await showDatePicker(
                                                        context: context,
                                                        initialDate: latest,
                                                        firstDate: _month,
                                                        lastDate: latest,
                                                        helpText: l(context,
                                                            'When did you give this payment?'));
                                                  }
                                                  if (paidOn == null ||
                                                      !context.mounted) {
                                                    return;
                                                  }
                                                  final confirmed = await showDialog<
                                                          bool>(
                                                      context: context,
                                                      builder: (ctx) =>
                                                          AlertDialog(
                                                              title: Text(l(
                                                                  context,
                                                                  "Record this month’s payment?")),
                                                              content: Text(l(
                                                                  context,
                                                                  "Confirm that you gave {0} {1} to {2}.{3}",
                                                                  [
                                                                    plan.currency,
                                                                    plan.amount.toStringAsFixed(
                                                                        currencyDecimals(
                                                                            plan.currency)),
                                                                    plan.recipient,
                                                                    plan.kind ==
                                                                            'zakat'
                                                                        ? l(context,
                                                                            " This will reduce the remaining amount on your selected Zakat record.")
                                                                        : l(context,
                                                                            " Your Zakat balance will not change.")
                                                                  ])),
                                                              actions: [
                                                                TextButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                            ctx,
                                                                            false),
                                                                    child: Text(l(
                                                                        context,
                                                                        "Not yet"))),
                                                                TextButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                            ctx,
                                                                            true),
                                                                    child: Text(l(
                                                                        context,
                                                                        "Yes, I paid")))
                                                              ]));
                                                  if (confirmed != true ||
                                                      !context.mounted) {
                                                    return;
                                                  }
                                                  final ok = await monthly
                                                      .markPaid(plan, key,
                                                          paidAt: paidOn);
                                                  if (ok && context.mounted) {
                                                    await showGivingCelebration(
                                                        context,
                                                        sadaqah: plan.kind ==
                                                            'sadaqah');
                                                  }
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(SnackBar(
                                                            content: Text(ok
                                                                ? l(
                                                                    context,
                                                                    "Payment recorded for {0}.",
                                                                    [
                                                                        plan.recipient
                                                                      ])
                                                                : l(
                                                                    context,
                                                                    monthly
                                                                        .error!))));
                                                  }
                                                },
                                          icon: const Icon(
                                              Icons.check_circle_outline),
                                          label:
                                              Text(l(context, "Mark as paid"))),
                                  ])));
                    }),
                    if (monthly.plans.any((p) => !p.active))
                      ExpansionTile(
                          title: Text(l(context, "Paused recipients")),
                          subtitle: Text(l(context,
                              "Resume from this month; previous payments stay saved")),
                          children: monthly.plans
                              .where((p) => !p.active)
                              .map((p) => ListTile(
                                  title: Text(p.recipient),
                                  trailing: TextButton(
                                      onPressed: monthly.busy
                                          ? null
                                          : () => _edit(plan: p),
                                      child:
                                          Text(l(context, "Edit & resume")))))
                              .toList()),
                    const SizedBox(height: 16),
                    Text(
                        l(context,
                            "Reminders are a prompt to give, not an automatic transfer. A commitment never reduces your Zakat until it is marked paid."),
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 12, height: 1.6)),
                  ])),
      floatingActionButton: all.isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: 'monthly-add',
              onPressed: monthly.busy ? null : () => _edit(),
              icon: const Icon(Icons.add),
              label: Text(l(context, "Add recipient"))),
    );
  }
}

class _MonthlyStat extends StatelessWidget {
  final String label;
  final String value;
  const _MonthlyStat(this.label, this.value);
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l(context, label)),
        const SizedBox(height: 6),
        Text(l(context, value),
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold))
      ]);
}

class MonthlyPlanDialog extends StatefulWidget {
  final MonthlyPlan? existing;
  final DateTime? initialMonth;
  const MonthlyPlanDialog({super.key, this.existing, this.initialMonth});
  @override
  State<MonthlyPlanDialog> createState() => _MonthlyPlanDialogState();
}

class _MonthlyPlanDialogState extends State<MonthlyPlanDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late String _currency;
  late String _kind;
  late String _record;
  late int _day;
  late DateTime _start;
  String? _error;
  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthProvider>().profile!;
    final p = widget.existing;
    _name = TextEditingController(text: p?.recipient ?? '');
    _amount = TextEditingController(text: p?.amount.toString() ?? '');
    _currency = p?.currency ?? profile.currency;
    _kind = p?.kind ?? profile.monthlyDefaultKind;
    _record = p?.zakatRecordId ?? '';
    _day = p?.reminderDay ?? 1;
    _start = p != null && p.active
        ? monthFromKey(p.startMonth)
        : DateTime((widget.initialMonth ?? DateTime.now()).year,
            (widget.initialMonth ?? DateTime.now()).month);
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final monthly = context.watch<MonthlyProvider>();
    final records = context
        .watch<CalculatorProvider>()
        .records
        .where((r) => r.isSubmitted && r.currency == _currency)
        .toList();
    final selected = records.any((r) => r.id == _record) ? _record : null;
    return AlertDialog(
        title: Text(widget.existing == null
            ? l(context, "Add monthly giving")
            : l(context, "Edit monthly commitment")),
        content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
                child: Form(
                    key: _form,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.existing != null)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(l(context,
                                    "Changes apply to unpaid and future months. Recorded payments keep their original amounts and classification."))),
                          TextFormField(
                              controller: _name,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                  labelText: l(context, "Recipient name")),
                              validator: (v) => v == null ||
                                      v.trim().isEmpty ||
                                      v.length > 120
                                  ? l(context,
                                      "Enter a name (up to 120 characters)")
                                  : null),
                          const SizedBox(height: 14),
                          TextFormField(
                              controller: _amount,
                              textDirection: TextDirection.ltr,
                              inputFormatters: const [GroupedAmountFormatter()],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: InputDecoration(
                                  labelText: l(context, "Amount per month")),
                              validator: (v) {
                                final n = parseLocalizedNumber(v ?? '');
                                return n == null ||
                                        !n.isFinite ||
                                        n <= 0 ||
                                        n >= 1e15
                                    ? l(context, "Enter a positive amount")
                                    : null;
                              }),
                          const SizedBox(height: 14),
                          SearchablePicker<String>(
                              label: l(context, "Currency"),
                              value: _currency,
                              options: currencyOptions,
                              onChanged: monthly.busy
                                  ? null
                                  : (v) => setState(() {
                                        _currency = v;
                                        _record = '';
                                      })),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                              value: _kind,
                              decoration: InputDecoration(
                                  labelText:
                                      l(context, "Count this giving as")),
                              items: [
                                DropdownMenuItem(
                                    value: 'sadaqah',
                                    child: Text(l(context, "صدقة · Sadaqah"))),
                                DropdownMenuItem(
                                    value: 'zakat',
                                    child: Text(
                                        l(context, "زكاة · Part of Zakat")))
                              ],
                              onChanged: monthly.busy
                                  ? null
                                  : (v) => setState(() => _kind = v!)),
                          if (_kind == 'zakat') ...[
                            const SizedBox(height: 14),
                            SearchablePicker<String>(
                                label: l(context, "Zakat record to reduce"),
                                value: selected,
                                options: records
                                    .map((r) => PickerOption(r.id, r.name))
                                    .toList(),
                                onChanged: monthly.busy
                                    ? null
                                    : (v) => setState(() => _record = v),
                                validator: (v) => _kind == 'zakat' && v == null
                                    ? l(context,
                                        "Choose a submitted record in the same currency")
                                    : null),
                            if (records.isEmpty)
                              Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(l(context,
                                      "Create and submit a Zakat calculation in this currency first. You can also choose Sadaqah for now."))),
                          ],
                          const SizedBox(height: 14),
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.history),
                              title: Text(l(context, 'First month')),
                              subtitle: Text(l(
                                  context, DateFormat.yMMMM().format(_start))),
                              trailing:
                                  const Icon(Icons.edit_calendar_outlined),
                              onTap: monthly.busy
                                  ? null
                                  : () async {
                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
                                      final picked = await showDatePicker(
                                          context: context,
                                          initialDate:
                                              _start.isAfter(DateTime.now())
                                                  ? DateTime.now()
                                                  : _start,
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime.now(),
                                          helpText: l(context,
                                              'Choose any day in the first month'));
                                      if (picked != null && mounted) {
                                        setState(() => _start = DateTime(
                                            picked.year, picked.month));
                                      }
                                    }),
                          Text(
                              l(context,
                                  'Choose an earlier month to record giving you already made. No payments are created automatically.'),
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 14),
                          SearchablePicker<int>(
                              label: l(context, "Remind me each month on day"),
                              value: _day,
                              options: List.generate(
                                  31, (i) => PickerOption(i + 1, '${i + 1}')),
                              onChanged: monthly.busy
                                  ? null
                                  : (v) => setState(() => _day = v)),
                          const SizedBox(height: 8),
                          Text(
                              l(context,
                                  "If a month is shorter, the reminder falls on its last day."),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                  height: 1.5)),
                          if (_error != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Text(l(context, _error!),
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error))),
                        ])))),
        actions: [
          TextButton(
              onPressed: monthly.busy ? null : () => Navigator.pop(context),
              child: Text(l(context, "Cancel"))),
          TextButton(
              onPressed: monthly.busy
                  ? null
                  : () async {
                      if (!_form.currentState!.validate()) return;
                      final p = widget.existing;
                      final plan = MonthlyPlan(
                          id: p?.id ?? const Uuid().v4(),
                          userId: context.read<AuthProvider>().user!.uid,
                          recipient: _name.text.trim(),
                          amount: parseLocalizedNumber(_amount.text)!,
                          currency: _currency,
                          kind: _kind,
                          zakatRecordId: _kind == 'zakat' ? _record : '',
                          reminderDay: _day,
                          startMonth: monthKey(_start),
                          active: true,
                          createdAt: p?.createdAt ?? DateTime.now());
                      final ok = await monthly.save(plan);
                      if (!context.mounted) return;
                      if (ok) {
                        Navigator.pop(context);
                      } else {
                        setState(() => _error = monthly.error);
                      }
                    },
              child: Text(monthly.busy
                  ? l(context, "Saving…")
                  : l(context, "Save recipient"))),
        ]);
  }
}

class MonthlySettings extends StatelessWidget {
  const MonthlySettings({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final monthly = context.watch<MonthlyProvider>();
    final profile = auth.profile!;
    return SafeArea(
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l(context, "Monthly giving settings"),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                      value: profile.monthlyDefaultKind,
                      isExpanded: true,
                      decoration: InputDecoration(
                          labelText: l(context, "Default for new recipients")),
                      items: [
                        DropdownMenuItem(
                            value: 'sadaqah',
                            child: Text(l(context, "صدقة · Sadaqah"))),
                        DropdownMenuItem(
                            value: 'zakat',
                            child: Text(l(context, "زكاة · Part of Zakat")))
                      ],
                      onChanged: (v) async {
                        final ok = await auth.updateProfileFields(
                            monthlyDefaultKind: v);
                        if (!context.mounted || ok) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l(context, auth.error!))));
                      }),
                  const SizedBox(height: 10),
                  Text(
                      l(context,
                          "Each recipient can override this. Changing the default never reclassifies existing payments."),
                      style:
                          const TextStyle(height: 1.5, color: Colors.black54)),
                  const SizedBox(height: 18),
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l(context, "Email me monthly reminders")),
                      subtitle: Text(l(
                          context,
                          "Sent to {0}. In-app reminders are always available.",
                          [auth.user?.email ?? profile.email])),
                      value: profile.monthlyEmailReminders,
                      onChanged: (v) async {
                        final ok = await auth.updateProfileFields(
                            monthlyEmailReminders: v);
                        if (!context.mounted || ok) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l(context, auth.error!))));
                      }),
                  if (!monthly.emailReady)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(l(context,
                                "Email delivery has not been confirmed yet. Your preference is saved; in-app due reminders are available now.")))),
                  Text(
                      l(context,
                          "Email reminders are checked daily around 08:00 UTC. One reminder per unpaid recipient per month; completed payments are skipped. Email includes the recipient and amount. You can turn it off at any time."),
                      style: const TextStyle(
                          fontSize: 12, height: 1.6, color: Colors.black54)),
                  const SizedBox(height: 16),
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l(context, "Done"))),
                ])));
  }
}
