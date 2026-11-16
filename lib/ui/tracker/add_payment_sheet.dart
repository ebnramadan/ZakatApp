import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
  final _recipientCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _amountCtrl.text = widget.existing!.amount.toStringAsFixed(2);
      _nameCtrl.text = widget.existing!.name;
      _recipientCtrl.text = widget.existing!.recipient;
      _date = widget.existing!.date;
    } else {
      final tracker = context.read<TrackerProvider>();
      final count = tracker.payments.length + 1;
      _nameCtrl.text = 'Payment $count';
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _nameCtrl.dispose();
    _recipientCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
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
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Manage this payment in شهريات.')));
      return;
    }
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || !amount.isFinite || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
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
        recipient: _recipientCtrl.text.trim(),
        createdAt: widget.existing!.createdAt,
      );
      await tracker.updatePayment(updated);
    } else {
      await tracker.addPayment(
        uid: auth.user!.uid,
        amount: amount,
        name: _nameCtrl.text.trim(),
        date: _date,
        recipient: _recipientCtrl.text.trim(),
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);
    if (tracker.error == null) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tracker.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<TrackerProvider>();
    final currency = tracker.selectedRecord?.currency ?? 'UNKNOWN';
    final dateFmt = DateFormat('d MMMM yyyy');

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(_isEdit ? 'Edit Payment' : 'Add Payment',
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
            ],
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '${currencySymbol(currency)} ',
              prefixStyle: const TextStyle(
                  color: kPrimaryGreen, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),

          TextField(
              controller: _nameCtrl,
              decoration:
                  const InputDecoration(labelText: 'Payment name (optional)')),
          if (tracker.payeeNames.isNotEmpty)
            Wrap(
                spacing: 6,
                children: tracker.payeeNames
                    .take(5)
                    .map((name) => ActionChip(
                        label: Text(name),
                        onPressed: () => _nameCtrl.text = name))
                    .toList()),
          const SizedBox(height: 12),

          // Date
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date',
                prefixIcon: Icon(Icons.calendar_today, size: 18),
              ),
              child: Text(dateFmt.format(_date)),
            ),
          ),
          const SizedBox(height: 12),

          // Recipient
          TextField(
            controller: _recipientCtrl,
            decoration:
                const InputDecoration(labelText: 'Recipient (optional)'),
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(_isEdit ? 'Save Changes' : 'Add Payment'),
          ),
        ],
      ),
    );
  }
}
