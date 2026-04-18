import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/models/zakat_record.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/calculator_provider.dart';
import '../widgets/nisab_chip.dart';
import '../widgets/amount_field.dart';
import 'results_screen.dart';

class OnePagerScreen extends StatefulWidget {
  const OnePagerScreen({super.key});

  @override
  State<OnePagerScreen> createState() => _OnePagerScreenState();
}

class _OnePagerScreenState extends State<OnePagerScreen> {
  final _nameCtrl = TextEditingController();
  final _cashCtrl = TextEditingController();
  bool _useHijri = false;
  DateTime _hawlDate = DateTime.now();

  List<ForeignCashEntry> _foreignEntries = [];
  List<GoldEntry> _goldEntries = [];

  late String _currency;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final calc = context.read<CalculatorProvider>();
    _currency = auth.profile!.currency;
    _nameCtrl.text = calc.draft?.name ?? '';
    calc.fetchPrices(_currency).then((_) {
      if (_goldEntries.isNotEmpty) return;
      setState(() => _goldEntries.add(
          GoldEntry(carat: 24, grams: 0, pricePerGram24k: calc.goldPricePerGram)));
    });
    if (_goldEntries.isEmpty) {
      _goldEntries.add(
          GoldEntry(carat: 24, grams: 0, pricePerGram24k: 0));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cashCtrl.dispose();
    super.dispose();
  }

  void _syncAll() {
    final calc = context.read<CalculatorProvider>();
    calc.updateDraftName(_nameCtrl.text);
    calc.updateDraftHawl(_hawlDate, _useHijri);
    calc.updateCashLocal(double.tryParse(_cashCtrl.text) ?? 0);
    calc.setForeignCash(List.from(_foreignEntries));
    calc.setGoldEntries(List.from(_goldEntries));
  }

  void _goToResults() {
    _syncAll();
    final calc = context.read<CalculatorProvider>();
    calc.computeResults();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ResultsScreen()));
  }

  String _displayDate() {
    if (_useHijri) {
      final h = HijriCalendar.fromDate(_hawlDate);
      return '${h.hDay} ${h.longMonthName} ${h.hYear} AH';
    }
    return DateFormat('d MMMM yyyy').format(_hawlDate);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: _hawlDate,
        firstDate: DateTime(2000),
        lastDate: DateTime.now());
    if (picked != null) setState(() => _hawlDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final calc = context.watch<CalculatorProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Zakat Calculator')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: NisabChip(
                nisabValue: calc.nisabValue,
                currency: _currency,
                isLoading: calc.pricesLoading),
          ),
          const SizedBox(height: 20),

          // ── Setup ──────────────────────────────────────────────────────
          _Section(title: 'Setup', children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Zakat Name'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Use Hijri calendar', style: TextStyle(fontSize: 13)),
                const Spacer(),
                Switch(
                  value: _useHijri,
                  onChanged: (v) => setState(() => _useHijri = v),
                  activeColor: kPrimaryGreen,
                ),
              ],
            ),
            const SizedBox(height: 4),
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
                    Text(_displayDate()),
                    const Spacer(),
                    const Text('Hawl start', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ]),

          // ── Cash Local ─────────────────────────────────────────────────
          _Section(title: 'Cash — Local ($_currency)', children: [
            AmountField(
              label: 'Total savings & cash',
              currency: _currency,
              controller: _cashCtrl,
            ),
          ]),

          // ── Cash Foreign ───────────────────────────────────────────────
          _Section(
            title: 'Cash — Foreign Currencies',
            trailing: TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
              onPressed: () => setState(() => _foreignEntries.add(
                    ForeignCashEntry(currency: 'USD', amount: 0, exchangeRate: 0))),
            ),
            children: _foreignEntries.isEmpty
                ? [const Text('No foreign currencies added.',
                    style: TextStyle(color: Colors.grey, fontSize: 13))]
                : _foreignEntries.asMap().entries.map((e) {
                    final i = e.key;
                    final entry = e.value;
                    return _ForeignRow(
                      index: i,
                      entry: entry,
                      localCurrency: _currency,
                      onChanged: (updated) => setState(() => _foreignEntries[i] = updated),
                      onRemove: () => setState(() => _foreignEntries.removeAt(i)),
                      onFetchRate: () async {
                        final rate = await calc.getExchangeRate(entry.currency, _currency);
                        setState(() => _foreignEntries[i] =
                            _foreignEntries[i].copyWith(exchangeRate: rate, isManualRate: false));
                      },
                    );
                  }).toList(),
          ),

          // ── Gold ───────────────────────────────────────────────────────
          _Section(
            title: 'Gold',
            trailing: TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
              onPressed: () => setState(() => _goldEntries.add(
                    GoldEntry(carat: 24, grams: 0, pricePerGram24k: calc.goldPricePerGram))),
            ),
            children: _goldEntries.asMap().entries.map((e) {
              final i = e.key;
              return _GoldRow(
                index: i,
                entry: e.value,
                currency: _currency,
                livePrice: calc.goldPricePerGram,
                onChanged: (updated) => setState(() => _goldEntries[i] = updated),
                onRemove: i == 0 ? null : () => setState(() => _goldEntries.removeAt(i)),
                onResetPrice: () => setState(() => _goldEntries[i] =
                    _goldEntries[i].copyWith(pricePerGram24k: calc.goldPricePerGram, isManualPrice: false)),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _goToResults,
            child: const Text('Calculate Zakat'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  const _Section({required this.title, required this.children, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: kPrimaryGreen)),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
        const Divider(height: 16),
        ...children,
        const SizedBox(height: 20),
      ],
    );
  }
}

class _ForeignRow extends StatefulWidget {
  final int index;
  final ForeignCashEntry entry;
  final String localCurrency;
  final void Function(ForeignCashEntry) onChanged;
  final VoidCallback onRemove;
  final Future<void> Function() onFetchRate;

  const _ForeignRow({
    required this.index,
    required this.entry,
    required this.localCurrency,
    required this.onChanged,
    required this.onRemove,
    required this.onFetchRate,
  });

  @override
  State<_ForeignRow> createState() => _ForeignRowState();
}

class _ForeignRowState extends State<_ForeignRow> {
  late TextEditingController _amtCtrl;
  late TextEditingController _rateCtrl;

  @override
  void initState() {
    super.initState();
    _amtCtrl = TextEditingController(
        text: widget.entry.amount != 0 ? widget.entry.amount.toStringAsFixed(2) : '');
    _rateCtrl = TextEditingController(
        text: widget.entry.exchangeRate != 0 ? widget.entry.exchangeRate.toStringAsFixed(4) : '');
  }

  @override
  void didUpdateWidget(_ForeignRow old) {
    super.didUpdateWidget(old);
    if (!widget.entry.isManualRate && widget.entry.exchangeRate != old.entry.exchangeRate) {
      _rateCtrl.text = widget.entry.exchangeRate.toStringAsFixed(4);
    }
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Text('Entry ${widget.index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close, color: Colors.red, size: 18), onPressed: widget.onRemove),
              ],
            ),
            DropdownButtonFormField<String>(
              value: kCurrencies.containsKey(widget.entry.currency) ? widget.entry.currency : null,
              decoration: const InputDecoration(labelText: 'Currency', isDense: true),
              items: kCurrencies.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text('${e.key} — ${e.value}')))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  widget.onChanged(widget.entry.copyWith(currency: v));
                  widget.onFetchRate();
                }
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amtCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    decoration: InputDecoration(labelText: 'Amount', isDense: true,
                        prefixText: '${currencySymbol(widget.entry.currency)} '),
                    onChanged: (v) => widget.onChanged(widget.entry.copyWith(amount: double.tryParse(v) ?? 0)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _rateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    decoration: InputDecoration(
                      labelText: 'Rate → ${widget.localCurrency}',
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.refresh, size: 16, color: kPrimaryGreen),
                        onPressed: widget.onFetchRate,
                      ),
                    ),
                    onChanged: (v) => widget.onChanged(
                        widget.entry.copyWith(exchangeRate: double.tryParse(v) ?? 0, isManualRate: true)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GoldRow extends StatefulWidget {
  final int index;
  final GoldEntry entry;
  final String currency;
  final double livePrice;
  final void Function(GoldEntry) onChanged;
  final VoidCallback? onRemove;
  final VoidCallback onResetPrice;

  const _GoldRow({
    required this.index,
    required this.entry,
    required this.currency,
    required this.livePrice,
    required this.onChanged,
    this.onRemove,
    required this.onResetPrice,
  });

  @override
  State<_GoldRow> createState() => _GoldRowState();
}

class _GoldRowState extends State<_GoldRow> {
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
            : widget.livePrice != 0 ? widget.livePrice.toStringAsFixed(2) : '');
  }

  @override
  void didUpdateWidget(_GoldRow old) {
    super.didUpdateWidget(old);
    if (!widget.entry.isManualPrice && widget.livePrice != old.livePrice && widget.livePrice != 0) {
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
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Text('Gold ${widget.index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (widget.onRemove != null)
                  IconButton(icon: const Icon(Icons.close, color: Colors.red, size: 18), onPressed: widget.onRemove),
              ],
            ),
            Row(
              children: [
                const Text('Carat:', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 8),
                ...([24, 21, 18]).map((c) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('${c}K', style: const TextStyle(fontSize: 12)),
                        selected: widget.entry.carat == c,
                        onSelected: (_) => widget.onChanged(widget.entry.copyWith(carat: c)),
                      ),
                    )),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _gramsCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    decoration: const InputDecoration(labelText: 'Grams', isDense: true, suffixText: 'g'),
                    onChanged: (v) => widget.onChanged(widget.entry.copyWith(grams: double.tryParse(v) ?? 0)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    decoration: InputDecoration(
                      labelText: '24K/g (${widget.currency})',
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.refresh, size: 16, color: kPrimaryGreen),
                        onPressed: widget.onResetPrice,
                      ),
                    ),
                    onChanged: (v) => widget.onChanged(
                        widget.entry.copyWith(pricePerGram24k: double.tryParse(v) ?? 0, isManualPrice: true)),
                  ),
                ),
              ],
            ),
            if (widget.entry.grams > 0 && widget.entry.pricePerGram24k > 0) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text('≈ ${fmt.format(widget.entry.localValue)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: kPrimaryGreen)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
