import '../../core/localization/strings.dart';
import '../shared/giving_celebration.dart';
import 'package:flutter/material.dart';
import '../../core/localization/amount_formatter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/constants.dart';
import '../../core/models/payment.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/tracker_provider.dart';

class AddPaymentSheet extends StatefulWidget {
  final Payment? existing;

  const AddPaymentSheet({super.key, this.existing});

  @override
  State<AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends State<AddPaymentSheet> {
  final _amountCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _amountCtrl.text = widget.existing!.amount.toStringAsFixed(2);
      _nameCtrl.text = widget.existing!.displayName;
      _date = widget.existing!.date;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(DateTime.now()) ? DateTime.now() : _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (widget.existing?.isMonthly == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l(context, "Manage this payment in شهريات."))));
      return;
    }
    final amount = parseLocalizedNumber(_amountCtrl.text);
    if (amount == null || !amount.isFinite || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l(context, "Enter a valid amount"))));
      return;
    }
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l(context, 'Enter a name'))));
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    final tracker = context.read<TrackerProvider>();

    if (_isEdit) {
      final updated = Payment(
        id: widget.existing!.id,
        zakatRecordId: widget.existing!.zakatRecordId,
        userId: widget.existing!.userId,
        amount: amount,
        name: _nameCtrl.text.trim(),
        date: _date,
        recipient: '',
        createdAt: widget.existing!.createdAt,
      );
      await tracker.updatePayment(updated);
    } else {
      await tracker.addPayment(
        uid: auth.user!.uid,
        amount: amount,
        name: _nameCtrl.text.trim(),
        date: _date,
        recipient: '',
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
    if (tracker.error == null) {
      if (!_isEdit) {
        await showGivingCelebration(context);
        if (!mounted) return;
      }
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l(context, tracker.error!))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<TrackerProvider>();
    final currency = tracker.selectedRecord?.currency;
    final dateFmt = DateFormat('d MMMM yyyy');

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.paddingOf(context).bottom +
            24,
      ),
      child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                      _isEdit
                          ? l(context, "Edit Payment")
                          : l(context, "Add Payment"),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: 16),

              // Amount
              TextFormField(
                controller: _amountCtrl,
                autofocus: !_isEdit,
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.next,
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: const [GroupedAmountFormatter()],
                decoration: InputDecoration(
                  labelText: l(context, "Amount"),
                  prefixText:
                      currency == null ? null : '${currencySymbol(currency)} ',
                  prefixStyle: const TextStyle(
                      color: kPrimaryGreen, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                      labelText: l(context, 'Name'),
                      hintText:
                          l(context, 'Who or what is this payment for?'))),
              const SizedBox(height: 12),

              // Date
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l(context, "Date"),
                    prefixIcon: const Icon(Icons.calendar_today, size: 18),
                  ),
                  child: Text(l(context, dateFmt.format(_date))),
                ),
              ),
              const SizedBox(height: 12),

              const SizedBox(height: 8),

              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(_isEdit
                        ? l(context, "Save Changes")
                        : l(context, "Add Payment")),
              ),
            ],
          )),
    );
  }
}
