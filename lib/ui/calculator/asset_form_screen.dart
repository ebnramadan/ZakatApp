import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/models/zakat_record.dart';
import '../../core/providers/calculator_provider.dart';
import 'results_screen.dart';

/// Both entry modes edit the same model and use the same validation engine.
class AssetFormScreen extends StatefulWidget {
  final bool guided;
  const AssetFormScreen({super.key, required this.guided});
  @override
  State<AssetFormScreen> createState() => _AssetFormScreenState();
}

class _AssetFormScreenState extends State<AssetFormScreen> {
  int _step = 0;
  final _form = GlobalKey<FormState>();
  final Set<ForeignCashEntry> _fetching = {};
  final Map<ForeignCashEntry, int> _requests = {};
  int _sequence = 0;
  bool _saving = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final calc = context.read<CalculatorProvider>();
      if (calc.draft?.currency != null && !calc.draft!.manualNisabPrice) {
        calc.fetchPrices(calc.draft!.currency!);
      }
    });
  }

  Widget _number(String label, double value, ValueChanged<double> change,
      {bool positive = false, Key? key}) {
    return _NumberInput(
      key: key,
      label: label,
      value: value,
      positive: positive,
      onChanged: (number) {
        change(number);
        setState(() {});
      },
    );
  }

  Future<void> _rate(ForeignCashEntry entry) async {
    final calc = context.read<CalculatorProvider>();
    final currency = entry.currency;
    final token = ++_sequence;
    _requests[entry] = token;
    setState(() => _fetching.add(entry));
    try {
      final rate = await calc.getExchangeRate(currency, calc.draft!.currency!);
      if (!mounted ||
          _requests[entry] != token ||
          !calc.draft!.foreignCash.contains(entry)) return;
      setState(() {
        entry.exchangeRate = rate;
        entry.isManualRate = false;
      });
      calc.draft!.pricedAt = DateTime.now();
    } catch (_) {
      if (mounted && _requests[entry] == token) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Rate unavailable. Enter a verified manual rate or retry.')));
      }
    } finally {
      if (mounted && _requests[entry] == token) {
        setState(() => _fetching.remove(entry));
      }
    }
  }

  Future<bool> _saveDraft() async {
    if (_saving) return false;
    final calc = context.read<CalculatorProvider>();
    setState(() => _saving = true);
    final ok = await calc.saveDraft();
    if (!mounted) return ok;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Draft saved' : calc.error!)));
    return ok;
  }

  Future<bool> _leave() async {
    if (_saving) return false;
    final answer = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Leave calculation?'),
              content: const Text(
                  'Save your draft to continue later, or leave without saving your latest changes.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, 'cancel'),
                    child: const Text('Keep editing')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, 'leave'),
                    child: const Text('Leave')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, 'save'),
                    child: const Text('Save draft')),
              ],
            ));
    if (answer == 'save') return _saveDraft();
    return answer == 'leave';
  }

  void _results() {
    final calc = context.read<CalculatorProvider>();
    if (!_form.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Check the inputs in all sections, including the gold price and exchange rates.')));
      return;
    }
    if (calc.computeResults()) {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const ResultsScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(calc.error ?? 'Check the calculation inputs.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final calc = context.watch<CalculatorProvider>();
    final d = calc.draft;
    if (d == null) {
      return const Scaffold(body: Center(child: Text('No active draft')));
    }
    final currency = d.currency;
    final sections = <Widget>[
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextFormField(
            initialValue: d.name,
            decoration: const InputDecoration(labelText: 'Record name'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Enter a name' : null,
            onChanged: (v) => d.name = v.trim()),
        const SizedBox(height: 12),
        if (currency == null)
          const Text(
              'This older draft has no saved currency. Choose its original currency before continuing.'),
        DropdownButtonFormField<String>(
            value: currency,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Record currency'),
            items: kCurrencies.keys
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: currency != null
                ? null
                : (v) {
                    setState(() => d.currency = v);
                  }),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show Hijri date'),
            subtitle: const Text('Hawl always lasts one lunar year.'),
            value: d.isHijriCalendar,
            onChanged: (v) => setState(() => d.isHijriCalendar = v)),
        ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hawl start'),
            subtitle: Text(d.isHijriCalendar
                ? HijriCalendar.fromDate(d.hawlStartDate)
                    .toFormat('dd MMMM yyyy')
                : DateFormat.yMMMd().format(d.hawlStartDate)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final selected = await showDatePicker(
                  context: context,
                  initialDate: d.hawlStartDate,
                  firstDate: DateTime(1938),
                  lastDate: DateTime.now());
              if (selected != null && mounted) {
                setState(() => d.hawlStartDate = selected);
              }
            }),
        Text('Lunar anniversary: ${DateFormat.yMMMd().format(d.hawlEndDate)}'),
        const SizedBox(height: 12),
        const Text(
            'Uses 85g pure gold Nisab and a 2.5% lunar-year rate. Includes cash and gold only, with no debt deductions. Confirm that wealth remained eligible throughout the Hawl. Estimates before the anniversary are not amounts currently due.'),
        _number('24K gold price per gram for Nisab (${currency ?? '?'})',
            d.goldPricePerGram24k, calc.updateGoldPrice,
            positive: true, key: const ValueKey('nisab-price')),
        Text(d.manualNisabPrice ? 'Manual Nisab price' : 'Live Nisab price'),
        if (d.pricedAt != null)
          Text(
              'Price/rate updated: ${DateFormat.yMd().add_Hm().format(d.pricedAt!)}'),
        TextButton.icon(
            onPressed: currency == null || calc.pricesLoading
                ? null
                : () {
                    d.manualNisabPrice = false;
                    calc.fetchPrices(currency);
                  },
            icon: const Icon(Icons.refresh),
            label: Text(calc.pricesLoading
                ? 'Fetching prices…'
                : 'Refresh live gold price')),
      ]),
      _number('Local cash (${currency ?? '?'})', d.cashLocal,
          (v) => d.cashLocal = v),
      Column(children: [
        ...d.foreignCash.map((entry) => Card(
            key: ObjectKey(entry),
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Row(children: [
                    const Text('Foreign cash'),
                    const Spacer(),
                    IconButton(
                        onPressed: () => setState(() {
                              d.foreignCash.remove(entry);
                              _requests.remove(entry);
                              _fetching.remove(entry);
                            }),
                        icon: const Icon(Icons.close))
                  ]),
                  DropdownButtonFormField<String>(
                      value: entry.currency,
                      isExpanded: true,
                      items: kCurrencies.keys
                          .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          entry.currency = v;
                          entry.exchangeRate = 0;
                          entry.isManualRate = false;
                        });
                        _rate(entry);
                      }),
                  _number('Amount (${entry.currency})', entry.amount,
                      (v) => entry.amount = v),
                  _number('1 ${entry.currency} = ? ${currency ?? '?'}',
                      entry.exchangeRate, (v) {
                    _requests[entry] = ++_sequence;
                    _fetching.remove(entry);
                    entry.exchangeRate = v;
                    entry.isManualRate = true;
                  }, positive: true, key: const ValueKey('foreign-rate')),
                  TextButton(
                      onPressed: currency == null || _fetching.contains(entry)
                          ? null
                          : () => _rate(entry),
                      child: Text(_fetching.contains(entry)
                          ? 'Fetching…'
                          : 'Refresh exchange rate')),
                ])))),
        OutlinedButton.icon(
            onPressed: currency == null
                ? null
                : () {
                    final entry = ForeignCashEntry(
                        currency: 'USD', amount: 0, exchangeRate: 0);
                    setState(() => d.foreignCash.add(entry));
                    _rate(entry);
                  },
            icon: const Icon(Icons.add),
            label: const Text('Add currency')),
      ]),
      Column(children: [
        ...d.goldEntries.map((entry) => Card(
            key: ObjectKey(entry),
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Row(children: [
                    const Text('Gold'),
                    const Spacer(),
                    IconButton(
                        onPressed: () =>
                            setState(() => d.goldEntries.remove(entry)),
                        icon: const Icon(Icons.close))
                  ]),
                  DropdownButtonFormField<int>(
                      value: entry.carat,
                      items: kGoldPurity.keys
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text('${c}K')))
                          .toList(),
                      onChanged: (v) => setState(() => entry.carat = v!)),
                  _number(
                      'Weight (grams)', entry.grams, (v) => entry.grams = v),
                  _number('24K price per gram (${currency ?? '?'})',
                      entry.pricePerGram24k, (v) {
                    entry.pricePerGram24k = v;
                    entry.isManualPrice = true;
                  },
                      positive: entry.grams > 0,
                      key: const ValueKey('gold-price')),
                  TextButton(
                      onPressed: () => setState(() {
                            entry.pricePerGram24k = d.goldPricePerGram24k;
                            entry.isManualPrice = false;
                          }),
                      child: const Text('Use Nisab gold price')),
                ])))),
        OutlinedButton.icon(
            onPressed: () => setState(() => d.goldEntries.add(
                GoldEntry(grams: 0, pricePerGram24k: d.goldPricePerGram24k))),
            icon: const Icon(Icons.add),
            label: const Text('Add gold')),
      ]),
    ];
    const titles = ['Setup', 'Local cash', 'Foreign cash', 'Gold'];
    return PopScope(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final leave = await _leave();
          if (!mounted || !leave) return;
          setState(() => _allowPop = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop();
          });
        },
        child: Scaffold(
          appBar: AppBar(
              title: Text(widget.guided ? titles[_step] : 'Zakat Calculator'),
              actions: [
                TextButton(
                    onPressed: _saving ? null : _saveDraft,
                    child: const Text('Save draft',
                        style: TextStyle(color: Colors.white))),
              ]),
          body: Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.all(20), children: [
                if (widget.guided)
                  LinearProgressIndicator(value: (_step + 1) / 4),
                if (calc.error != null)
                  Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(calc.error!,
                          style: const TextStyle(color: Colors.red))),
                ...List.generate(
                    4,
                    (i) => Offstage(
                        offstage: widget.guided && _step != i,
                        child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(titles[i],
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge),
                                  const SizedBox(height: 12),
                                  sections[i],
                                ])))),
                if (widget.guided && _step > 0)
                  TextButton(
                      onPressed: () => setState(() => _step--),
                      child: const Text('Previous')),
                ElevatedButton(
                    onPressed:
                        _saving || calc.pricesLoading || _fetching.isNotEmpty
                            ? null
                            : () {
                                if (widget.guided && _step < 3) {
                                  setState(() => _step++);
                                } else {
                                  _results();
                                }
                              },
                    child: Text(widget.guided && _step < 3
                        ? 'Next'
                        : 'Calculate Zakat')),
              ])),
        ));
  }
}

class _NumberInput extends StatefulWidget {
  final String label;
  final double value;
  final bool positive;
  final ValueChanged<double> onChanged;
  const _NumberInput(
      {super.key,
      required this.label,
      required this.value,
      required this.positive,
      required this.onChanged});
  @override
  State<_NumberInput> createState() => _NumberInputState();
}

class _NumberInputState extends State<_NumberInput> {
  late final TextEditingController _controller;
  final _focus = FocusNode();
  bool _typing = false;
  String get _formatted => widget.value == 0 ? '' : widget.value.toString();
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatted);
    _focus.addListener(_focusChanged);
  }

  void _focusChanged() {
    if (!_focus.hasFocus) {
      _typing = false;
      _sync();
    }
  }

  void _sync() {
    if (widget.value.isFinite &&
        double.tryParse(_controller.text.trim().isEmpty
                ? '0'
                : _controller.text.trim()) !=
            widget.value) {
      _controller.text = _formatted;
    }
  }

  @override
  void didUpdateWidget(covariant _NumberInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_typing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_typing) _sync();
      });
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: TextFormField(
          controller: _controller,
          focusNode: _focus,
          decoration: InputDecoration(labelText: widget.label),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (text) {
            final number =
                double.tryParse(text!.trim().isEmpty ? '0' : text.trim());
            return number == null ||
                    !number.isFinite ||
                    number < 0 ||
                    (widget.positive && number == 0)
                ? 'Enter a valid ${widget.positive ? 'positive ' : ''}number'
                : null;
          },
          onChanged: (text) {
            _typing = true;
            widget.onChanged(
                double.tryParse(text.trim().isEmpty ? '0' : text.trim()) ??
                    double.nan);
          },
        ),
      );
}
