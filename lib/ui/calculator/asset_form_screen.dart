import 'dart:convert';
import '../../core/localization/amount_formatter.dart';
import '../../core/localization/strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/constants.dart';
import '../../core/models/zakat_record.dart';
import '../../core/providers/calculator_provider.dart';
import '../../core/providers/auth_provider.dart';
import 'results_screen.dart';
import '../widgets/searchable_picker.dart';

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
  bool _showDetails = false;
  int _detailsRevision = 0;
  final Set<ForeignCashEntry> _fetching = {};
  final Map<ForeignCashEntry, int> _requests = {};
  int _sequence = 0;
  bool _saving = false;
  bool _allowPop = false;
  late String _savedInput;

  String _inputSnapshot() {
    final d = context.read<CalculatorProvider>().draft;
    if (d == null) return '';
    return jsonEncode({
      'name': d.name,
      'currency': d.currency,
      'hawl': d.hawlStartDate.millisecondsSinceEpoch,
      'hijri': d.isHijriCalendar,
      'cash': d.cashLocal,
      'manualPrice': d.manualNisabPrice ? d.goldPricePerGram24k : null,
      'foreign': d.foreignCash
          .map((e) =>
              [e.currency, e.amount, e.isManualRate ? e.exchangeRate : null])
          .toList(),
      'gold': d.goldEntries
          .map((e) =>
              [e.carat, e.grams, e.isManualPrice ? e.pricePerGram24k : null])
          .toList(),
    });
  }

  @override
  void initState() {
    super.initState();
    _savedInput = _inputSnapshot();
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l(context,
                "Rate unavailable. Enter a verified manual rate or retry."))));
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
    final auth = context.read<AuthProvider>();
    final defaultId = calc.defaultIdForDraft(auth.profile?.defaultRecordId);
    final ok = await calc.saveDraft();
    if (!mounted) return ok;
    if (ok && calc.draft != null) {
      _savedInput = _inputSnapshot();
      context
          .read<AuthProvider>()
          .updateProfileFields(defaultRecordId: defaultId)
          .then((saved) {
        if (!saved && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(l(context,
                  "Draft saved. Open records from Home and choose Set as default to update Home."))));
        }
      });
    }
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(ok ? l(context, "Draft saved") : l(context, calc.error!))));
    return ok;
  }

  Future<bool> _leave() async {
    if (_saving) return false;
    if (_inputSnapshot() == _savedInput) return true;
    FocusManager.instance.primaryFocus?.unfocus();
    final answer = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(l(context, "Leave calculation?")),
              content: Text(l(context,
                  "Save your draft to continue later, or leave without saving your latest changes.")),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, 'cancel'),
                    child: Text(l(context, "Keep editing"))),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, 'leave'),
                    child: Text(l(context, "Leave"))),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, 'save'),
                    child: Text(l(context, "Save draft"))),
              ],
            ));
    if (answer == 'save') return _saveDraft();
    return answer == 'leave';
  }

  bool _checkGoldPrice() {
    final draft = context.read<CalculatorProvider>().draft;
    if (draft == null ||
        draft.goldPricePerGram24k > 0 && draft.goldPricePerGram24k.isFinite) {
      return true;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _step = 0;
      _showDetails = true;
      _detailsRevision++;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            l(context, 'Add the gold price in More details to continue.'))));
    return false;
  }

  void _results() {
    final calc = context.read<CalculatorProvider>();
    if (!_checkGoldPrice()) return;
    if (!_form.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l(context,
              "Check the inputs in all sections, including the gold price and exchange rates."))));
      return;
    }
    if (calc.computeResults()) {
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const ResultsScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(l(context, calc.error ?? 'Check the calculation inputs.'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final calc = context.watch<CalculatorProvider>();
    final d = calc.draft;
    if (d == null) {
      return Scaffold(body: Center(child: Text(l(context, "No active draft"))));
    }
    final currency = d.currency;
    final sections = <Widget>[
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextFormField(
            initialValue: d.name,
            decoration: InputDecoration(labelText: l(context, "Record name")),
            validator: (v) => v == null || v.trim().isEmpty
                ? l(context, "Enter a name")
                : null,
            onChanged: (v) => d.name = v.trim()),
        const SizedBox(height: 12),
        if (currency == null)
          Text(l(context,
              "This older draft has no saved currency. Choose its original currency before continuing.")),
        SearchablePicker<String>(
            label: l(context, "Record currency"),
            value: currency,
            options: currencyOptions,
            helperText: l(context,
                "Amounts stay in the selected currency; they are not converted."),
            onChanged: (v) async {
              if (v == currency) return;
              if (d.cashLocal > 0 ||
                  d.foreignCash.isNotEmpty ||
                  d.goldEntries.isNotEmpty) {
                final yes = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                            title: Text(l(context, "Change record currency?")),
                            content: Text(l(context,
                                "Existing amounts are not converted. Gold prices and exchange rates will refresh; check all amounts before calculating.")),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(l(context, "Cancel"))),
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(l(context, "Change currency")))
                            ]));
                if (yes != true || !mounted) return;
              }
              setState(() {
                d.currency = v;
                d.manualNisabPrice = false;
                d.goldPricePerGram24k = 0;
                for (final e in d.goldEntries) {
                  e.pricePerGram24k = 0;
                  e.isManualPrice = false;
                }
                for (final e in d.foreignCash) {
                  e.exchangeRate = 0;
                  e.isManualRate = false;
                }
              });
              calc.fetchPrices(v);
              for (final e in d.foreignCash) {
                _rate(e);
              }
            }),
        ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l(context, "Hawl start")),
            subtitle: Text(d.isHijriCalendar
                ? l(
                    context,
                    HijriCalendar.fromDate(d.hawlStartDate)
                        .toFormat('dd MMMM yyyy'))
                : l(context, DateFormat.yMMMd().format(d.hawlStartDate))),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              FocusManager.instance.primaryFocus?.unfocus();
              final selected = await showDatePicker(
                  context: context,
                  initialDate: d.hawlStartDate,
                  firstDate: DateTime(1938),
                  lastDate: DateTime.now());
              if (selected != null && mounted) {
                setState(() => d.hawlStartDate = selected);
              }
            }),
        ExpansionTile(
          key: ValueKey('calculation-details-$_detailsRevision'),
          initiallyExpanded: _showDetails,
          onExpansionChanged: (expanded) => _showDetails = expanded,
          tilePadding: EdgeInsets.zero,
          title: Text(l(context, 'More details')),
          subtitle: Text(l(context, 'Nisab, gold price and Hijri date')),
          children: [
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l(context, "Show Hijri date")),
                subtitle: Text(l(context, "Hawl always lasts one lunar year.")),
                value: d.isHijriCalendar,
                onChanged: (v) => setState(() => d.isHijriCalendar = v)),
            Text(l(context, "Lunar anniversary: {0}",
                [DateFormat.yMMMd().format(d.hawlEndDate)])),
            const SizedBox(height: 12),
            Text(l(context,
                "Uses 85g pure gold Nisab and a 2.5% lunar-year rate. Includes cash and gold only, with no debt deductions. Confirm that wealth remained eligible throughout the Hawl. Amounts before your Zakat date are not currently due.")),
            _number('24K gold price per gram for Nisab (${currency ?? '?'})',
                d.goldPricePerGram24k, calc.updateGoldPrice,
                positive: true, key: const ValueKey('nisab-price')),
            Text(d.manualNisabPrice
                ? l(context, "Manual Nisab price")
                : l(context, "Live Nisab price")),
            if (d.pricedAt != null)
              Text(l(context, "Price/rate updated: {0}",
                  [DateFormat.yMd().add_Hm().format(d.pricedAt!)])),
            TextButton.icon(
                onPressed: currency == null || calc.pricesLoading
                    ? null
                    : () {
                        d.manualNisabPrice = false;
                        calc.fetchPrices(currency);
                      },
                icon: const Icon(Icons.refresh),
                label: Text(calc.pricesLoading
                    ? l(context, "Fetching prices…")
                    : l(context, "Refresh live gold price"))),
          ],
        ),
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
                    Text(l(context, "Foreign cash")),
                    const Spacer(),
                    IconButton(
                        onPressed: () => setState(() {
                              d.foreignCash.remove(entry);
                              _requests.remove(entry);
                              _fetching.remove(entry);
                            }),
                        icon: const Icon(Icons.close))
                  ]),
                  SearchablePicker<String>(
                      label: l(context, "Foreign currency"),
                      value: entry.currency,
                      options: currencyOptions,
                      onChanged: (v) {
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
                          ? l(context, "Fetching…")
                          : l(context, "Refresh exchange rate"))),
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
            label: Text(l(context, "Add currency"))),
      ]),
      Column(children: [
        ...d.goldEntries.map((entry) => Card(
            key: ObjectKey(entry),
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Row(children: [
                    Text(l(context, "Gold")),
                    const Spacer(),
                    IconButton(
                        onPressed: () =>
                            setState(() => d.goldEntries.remove(entry)),
                        icon: const Icon(Icons.close))
                  ]),
                  SegmentedButton<int>(
                      segments: kGoldPurity.keys
                          .map((c) => ButtonSegment(
                              value: c, label: Text(l(context, "{0}K", [c]))))
                          .toList(),
                      selected: {entry.carat},
                      onSelectionChanged: (v) =>
                          setState(() => entry.carat = v.single)),
                  _number(
                      'Weight (grams)', entry.grams, (v) => entry.grams = v),
                  _number('24K price per gram (${currency ?? '?'})',
                      entry.pricePerGram24k, (v) {
                    entry.pricePerGram24k = v;
                    entry.isManualPrice = true;
                  },
                      positive: entry.grams > 0,
                      key: const ValueKey('gold-price')),
                  if (entry.pricePerGram24k.isFinite &&
                      entry.grams.isFinite) ...[
                    const SizedBox(height: 12),
                    Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                            l(context, "{0}K price: {1} {2} / g", [
                              entry.carat,
                              currency ?? '?',
                              (entry.pricePerGram24k * entry.purity)
                                  .toStringAsFixed(2)
                            ]),
                            key: const ValueKey('effective-gold-price'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: kPrimaryGreen))),
                    Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                            l(context, "Gold value: {0} {1}", [
                              currency ?? '?',
                              entry.localValue.toStringAsFixed(2)
                            ]),
                            key: const ValueKey('gold-live-value'))),
                  ],
                  TextButton(
                      onPressed: () => setState(() {
                            entry.pricePerGram24k = d.goldPricePerGram24k;
                            entry.isManualPrice = false;
                          }),
                      child: Text(l(context, "Use Nisab gold price"))),
                ])))),
        OutlinedButton.icon(
            onPressed: () => setState(() => d.goldEntries.add(
                GoldEntry(grams: 0, pricePerGram24k: d.goldPricePerGram24k))),
            icon: const Icon(Icons.add),
            label: Text(l(context, "Add gold"))),
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
              title: Text(widget.guided
                  ? l(context, titles[_step])
                  : l(context, "Zakat Calculator")),
              actions: [
                TextButton(
                    onPressed: _saving ? null : _saveDraft,
                    child: Text(l(context, "Save draft"),
                        style: const TextStyle(color: kPrimaryGreen))),
              ]),
          body: Form(
              key: _form,
              child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                      20, 12, 20, 24 + MediaQuery.paddingOf(context).bottom),
                  children: [
                    if (widget.guided)
                      LinearProgressIndicator(value: (_step + 1) / 4),
                    if (calc.error != null)
                      Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(l(context, calc.error!),
                              style: const TextStyle(color: Colors.red))),
                    ...List.generate(
                        4,
                        (i) => Offstage(
                            offstage: widget.guided && _step != i,
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(l(context, titles[i]),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge),
                                      const SizedBox(height: 12),
                                      sections[i],
                                    ])))),
                    if (widget.guided && _step > 0)
                      TextButton(
                          onPressed: () {
                            FocusManager.instance.primaryFocus?.unfocus();
                            setState(() => _step--);
                          },
                          child: Text(l(context, "Previous"))),
                    ElevatedButton(
                        onPressed: _saving ||
                                calc.pricesLoading ||
                                _fetching.isNotEmpty
                            ? null
                            : () {
                                if (widget.guided && _step < 3) {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  if (_step == 0 && !_checkGoldPrice()) return;
                                  setState(() => _step++);
                                } else {
                                  _results();
                                }
                              },
                        child: Text(widget.guided && _step < 3
                            ? l(context, "Next")
                            : l(context, "Calculate Zakat"))),
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
        parseLocalizedNumber(_controller.text.trim().isEmpty
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
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _focus.unfocus(),
          onTapOutside: (_) => _focus.unfocus(),
          decoration: InputDecoration(labelText: l(context, widget.label)),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textDirection: TextDirection.ltr,
          inputFormatters: const [GroupedAmountFormatter()],
          validator: (text) {
            final number =
                parseLocalizedNumber(text!.trim().isEmpty ? '0' : text.trim());
            return number == null ||
                    !number.isFinite ||
                    number < 0 ||
                    (widget.positive && number == 0)
                ? l(context, "Enter a valid {0}number",
                    [widget.positive ? l(context, "positive ") : ''])
                : null;
          },
          onChanged: (text) {
            _typing = true;
            widget.onChanged(
                parseLocalizedNumber(text.trim().isEmpty ? '0' : text.trim()) ??
                    double.nan);
          },
        ),
      );
}
