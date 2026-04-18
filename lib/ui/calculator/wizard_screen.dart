import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/models/zakat_record.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/calculator_provider.dart';
import '../widgets/amount_field.dart';
import '../widgets/nisab_chip.dart';
import 'results_screen.dart';

class WizardScreen extends StatefulWidget {
  const WizardScreen({super.key});

  @override
  State<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends State<WizardScreen> {
  int _step = 0;
  final _pageCtrl = PageController();
  final List<String> _stepTitles = [
    'Setup',
    'Cash — Local',
    'Cash — Foreign',
    'Gold',
  ];

  void _next() {
    if (_step < _stepTitles.length - 1) {
      setState(() => _step++);
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _goToResults();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _goToResults() {
    final calc = context.read<CalculatorProvider>();
    calc.computeResults();
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ResultsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final calc = context.watch<CalculatorProvider>();
    final auth = context.read<AuthProvider>();
    final currency = auth.profile!.currency;

    return Scaffold(
      appBar: AppBar(
        title: Text(_stepTitles[_step]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _back,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / _stepTitles.length,
            backgroundColor: Colors.white38,
            valueColor: const AlwaysStoppedAnimation<Color>(kGold),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: NisabChip(
              nisabValue: calc.nisabValue,
              currency: currency,
              isLoading: calc.pricesLoading,
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _SetupStep(onInit: () => calc.fetchPrices(currency)),
                _CashLocalStep(currency: currency),
                _CashForeignStep(currency: currency),
                _GoldStep(currency: currency),
              ],
            ),
          ),
          _Footer(step: _step, total: _stepTitles.length, onNext: _next),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 1: Setup
// ─────────────────────────────────────────────────────────────────────────────
class _SetupStep extends StatefulWidget {
  final VoidCallback onInit;
  const _SetupStep({required this.onInit});

  @override
  State<_SetupStep> createState() => _SetupStepState();
}

class _SetupStepState extends State<_SetupStep> {
  late TextEditingController _nameCtrl;
  bool _useHijri = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final calc = context.read<CalculatorProvider>();
    _nameCtrl = TextEditingController(text: calc.draft?.name ?? '');
    widget.onInit();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      context.read<CalculatorProvider>().updateDraftHawl(picked, _useHijri);
    }
  }

  String _displayDate() {
    if (_useHijri) {
      final h = HijriCalendar.fromDate(_selectedDate);
      return '${h.hDay} ${h.longMonthName} ${h.hYear} AH';
    }
    return DateFormat('d MMMM yyyy').format(_selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    final calc = context.read<CalculatorProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Give this Zakat record a name',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Zakat Name'),
            onChanged: calc.updateDraftName,
          ),
          const SizedBox(height: 24),
          const Text('Hawl Start Date',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Use Hijri calendar', style: TextStyle(fontSize: 13)),
              const Spacer(),
              Switch(
                value: _useHijri,
                onChanged: (v) {
                  setState(() => _useHijri = v);
                  calc.updateDraftHawl(_selectedDate, v);
                },
                activeColor: kPrimaryGreen,
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFCCCCCC)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 18, color: kPrimaryGreen),
                  const SizedBox(width: 10),
                  Text(_displayDate(), style: const TextStyle(fontSize: 15)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2: Cash Local
// ─────────────────────────────────────────────────────────────────────────────
class _CashLocalStep extends StatefulWidget {
  final String currency;
  const _CashLocalStep({required this.currency});

  @override
  State<_CashLocalStep> createState() => _CashLocalStepState();
}

class _CashLocalStepState extends State<_CashLocalStep> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    final draft = context.read<CalculatorProvider>().draft;
    _ctrl = TextEditingController(
        text: draft?.cashLocal != 0 ? draft!.cashLocal.toString() : '');
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final calc = context.read<CalculatorProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter all cash, savings, and current account balances in your local currency.',
              style: TextStyle(color: Colors.grey, height: 1.5)),
          const SizedBox(height: 24),
          AmountField(
            label: 'Total Cash (${widget.currency})',
            currency: widget.currency,
            controller: _ctrl,
            onChanged: (v) => calc.updateCashLocal(double.tryParse(v) ?? 0),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3: Cash Foreign
// ─────────────────────────────────────────────────────────────────────────────
class _CashForeignStep extends StatefulWidget {
  final String currency;
  const _CashForeignStep({required this.currency});

  @override
  State<_CashForeignStep> createState() => _CashForeignStepState();
}

class _CashForeignStepState extends State<_CashForeignStep> {
  List<ForeignCashEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _entries = List.from(
        context.read<CalculatorProvider>().draft?.foreignCash ?? []);
  }

  void _add() {
    setState(() => _entries.add(ForeignCashEntry(
          currency: 'USD',
          amount: 0,
          exchangeRate: 0,
        )));
  }

  void _remove(int i) {
    setState(() => _entries.removeAt(i));
    _sync();
  }

  void _sync() {
    context.read<CalculatorProvider>().setForeignCash(List.from(_entries));
  }

  Future<void> _fetchRate(int i) async {
    final calc = context.read<CalculatorProvider>();
    final rate = await calc.getExchangeRate(_entries[i].currency, widget.currency);
    setState(() {
      _entries[i] = _entries[i].copyWith(exchangeRate: rate, isManualRate: false);
    });
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add any cash held in foreign currencies.',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ..._entries.asMap().entries.map((e) => _ForeignEntry(
                index: e.key,
                entry: e.value,
                localCurrency: widget.currency,
                onCurrencyChange: (c) {
                  setState(() => _entries[e.key] = _entries[e.key].copyWith(currency: c));
                  _fetchRate(e.key);
                },
                onAmountChange: (a) {
                  setState(() => _entries[e.key] = _entries[e.key].copyWith(amount: double.tryParse(a) ?? 0));
                  _sync();
                },
                onRateChange: (r) {
                  setState(() => _entries[e.key] = _entries[e.key].copyWith(
                      exchangeRate: double.tryParse(r) ?? 0, isManualRate: true));
                  _sync();
                },
                onFetchRate: () => _fetchRate(e.key),
                onRemove: () => _remove(e.key),
              )),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('Add Currency'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
          ),
        ],
      ),
    );
  }
}

class _ForeignEntry extends StatefulWidget {
  final int index;
  final ForeignCashEntry entry;
  final String localCurrency;
  final void Function(String) onCurrencyChange;
  final void Function(String) onAmountChange;
  final void Function(String) onRateChange;
  final VoidCallback onFetchRate;
  final VoidCallback onRemove;

  const _ForeignEntry({
    required this.index,
    required this.entry,
    required this.localCurrency,
    required this.onCurrencyChange,
    required this.onAmountChange,
    required this.onRateChange,
    required this.onFetchRate,
    required this.onRemove,
  });

  @override
  State<_ForeignEntry> createState() => _ForeignEntryState();
}

class _ForeignEntryState extends State<_ForeignEntry> {
  late TextEditingController _amountCtrl;
  late TextEditingController _rateCtrl;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
        text: widget.entry.amount != 0 ? widget.entry.amount.toStringAsFixed(2) : '');
    _rateCtrl = TextEditingController(
        text: widget.entry.exchangeRate != 0 ? widget.entry.exchangeRate.toStringAsFixed(4) : '');
  }

  @override
  void didUpdateWidget(_ForeignEntry old) {
    super.didUpdateWidget(old);
    if (!widget.entry.isManualRate && widget.entry.exchangeRate != old.entry.exchangeRate) {
      _rateCtrl.text = widget.entry.exchangeRate.toStringAsFixed(4);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final local = NumberFormat.currency(
        symbol: currencySymbol(widget.localCurrency), decimalDigits: 2);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Text('Currency ${widget.index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  onPressed: widget.onRemove,
                ),
              ],
            ),
            DropdownButtonFormField<String>(
              value: kCurrencies.containsKey(widget.entry.currency) ? widget.entry.currency : null,
              decoration: const InputDecoration(labelText: 'Currency'),
              items: kCurrencies.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text('${e.key} — ${e.value}')))
                  .toList(),
              onChanged: (v) { if (v != null) widget.onCurrencyChange(v); },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              onChanged: widget.onAmountChange,
              decoration: InputDecoration(
                labelText: 'Amount (${widget.entry.currency})',
                prefixText: '${currencySymbol(widget.entry.currency)} ',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _rateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    onChanged: widget.onRateChange,
                    decoration: InputDecoration(
                      labelText: '1 ${widget.entry.currency} = ? ${widget.localCurrency}',
                      helperText: widget.entry.isManualRate ? 'Manual override' : 'Live rate',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh, color: kPrimaryGreen),
                  tooltip: 'Refresh live rate',
                  onPressed: widget.onFetchRate,
                ),
              ],
            ),
            if (widget.entry.exchangeRate > 0 && widget.entry.amount > 0) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '≈ ${local.format(widget.entry.localValue)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: kPrimaryGreen),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 4: Gold
// ─────────────────────────────────────────────────────────────────────────────
class _GoldStep extends StatefulWidget {
  final String currency;
  const _GoldStep({required this.currency});

  @override
  State<_GoldStep> createState() => _GoldStepState();
}

class _GoldStepState extends State<_GoldStep> {
  List<GoldEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    final calc = context.read<CalculatorProvider>();
    _entries = List.from(calc.draft?.goldEntries ?? []);
    if (_entries.isEmpty) _add();
  }

  void _add() {
    final price = context.read<CalculatorProvider>().goldPricePerGram;
    setState(() => _entries.add(GoldEntry(carat: 24, grams: 0, pricePerGram24k: price)));
  }

  void _remove(int i) {
    setState(() => _entries.removeAt(i));
    _sync();
  }

  void _sync() {
    context.read<CalculatorProvider>().setGoldEntries(List.from(_entries));
  }

  @override
  Widget build(BuildContext context) {
    final calc = context.watch<CalculatorProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter gold holdings. Price is fetched live and can be overridden.',
              style: TextStyle(color: Colors.grey, height: 1.5)),
          const SizedBox(height: 16),
          ..._entries.asMap().entries.map((e) => _GoldEntry(
                index: e.key,
                entry: e.value,
                currency: widget.currency,
                livePrice: calc.goldPricePerGram,
                onCaratChange: (c) {
                  setState(() => _entries[e.key] = _entries[e.key].copyWith(carat: c));
                  _sync();
                },
                onGramsChange: (g) {
                  setState(() => _entries[e.key] = _entries[e.key].copyWith(grams: double.tryParse(g) ?? 0));
                  _sync();
                },
                onPriceChange: (p) {
                  setState(() => _entries[e.key] = _entries[e.key].copyWith(
                      pricePerGram24k: double.tryParse(p) ?? 0, isManualPrice: true));
                  _sync();
                },
                onResetPrice: () {
                  setState(() => _entries[e.key] = _entries[e.key].copyWith(
                      pricePerGram24k: calc.goldPricePerGram, isManualPrice: false));
                  _sync();
                },
                onRemove: () => _remove(e.key),
              )),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('Add Gold Entry'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
          ),
        ],
      ),
    );
  }
}

class _GoldEntry extends StatefulWidget {
  final int index;
  final GoldEntry entry;
  final String currency;
  final double livePrice;
  final void Function(int) onCaratChange;
  final void Function(String) onGramsChange;
  final void Function(String) onPriceChange;
  final VoidCallback onResetPrice;
  final VoidCallback onRemove;

  const _GoldEntry({
    required this.index,
    required this.entry,
    required this.currency,
    required this.livePrice,
    required this.onCaratChange,
    required this.onGramsChange,
    required this.onPriceChange,
    required this.onResetPrice,
    required this.onRemove,
  });

  @override
  State<_GoldEntry> createState() => _GoldEntryState();
}

class _GoldEntryState extends State<_GoldEntry> {
  late TextEditingController _gramsCtrl;
  late TextEditingController _priceCtrl;

  @override
  void initState() {
    super.initState();
    _gramsCtrl = TextEditingController(
        text: widget.entry.grams != 0 ? widget.entry.grams.toString() : '');
    _priceCtrl = TextEditingController(
        text: widget.entry.pricePerGram24k != 0
            ? widget.entry.pricePerGram24k.toStringAsFixed(2)
            : '');
  }

  @override
  void didUpdateWidget(_GoldEntry old) {
    super.didUpdateWidget(old);
    if (!widget.entry.isManualPrice && widget.livePrice != old.livePrice) {
      _priceCtrl.text = widget.livePrice.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _gramsCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: currencySymbol(widget.currency), decimalDigits: 2);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Text('Gold Entry ${widget.index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (widget.index > 0)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: widget.onRemove,
                  ),
              ],
            ),
            // Carat selector
            Row(
              children: [
                const Text('Carat: ', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: 12),
                ...([24, 21, 18]).map((c) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${c}K'),
                        selected: widget.entry.carat == c,
                        onSelected: (_) => widget.onCaratChange(c),
                      ),
                    )),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _gramsCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              onChanged: widget.onGramsChange,
              decoration: const InputDecoration(
                labelText: 'Weight (grams)',
                suffixText: 'g',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    onChanged: widget.onPriceChange,
                    decoration: InputDecoration(
                      labelText: '24K price per gram (${widget.currency})',
                      helperText: widget.entry.isManualPrice ? 'Manual override' : 'Live price',
                      prefixText: '${currencySymbol(widget.currency)} ',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh, color: kPrimaryGreen),
                  tooltip: 'Reset to live price',
                  onPressed: widget.onResetPrice,
                ),
              ],
            ),
            if (widget.entry.grams > 0 && widget.entry.pricePerGram24k > 0) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '≈ ${fmt.format(widget.entry.localValue)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: kPrimaryGreen),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Footer navigation
// ─────────────────────────────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  final int step;
  final int total;
  final VoidCallback onNext;

  const _Footer({required this.step, required this.total, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Step ${step + 1} of $total',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(minimumSize: const Size(140, 48)),
            child: Text(step == total - 1 ? 'See Results' : 'Next'),
          ),
        ],
      ),
    );
  }
}
