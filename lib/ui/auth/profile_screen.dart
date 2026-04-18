import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants.dart';
import '../../core/models/user_profile.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/calculator_provider.dart';
import '../../core/models/zakat_record.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  bool _editingName = false;
  String? _selectedCurrency;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthProvider>().profile;
    if (profile != null) {
      _nameCtrl.text = profile.displayName;
      _selectedCurrency = profile.currency;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile(AuthProvider auth) async {
    final profile = auth.profile!;
    await auth.updateProfile(profile.copyWith(
      displayName: _nameCtrl.text.trim(),
      currency: _selectedCurrency,
    ));
    setState(() => _editingName = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final calc = context.watch<CalculatorProvider>();
    final profile = auth.profile;
    if (profile == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          TextButton(
            onPressed: auth.signOut,
            child: const Text('Sign out', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Avatar(profile: profile),
          const SizedBox(height: 24),
          _NameField(
            ctrl: _nameCtrl,
            editing: _editingName,
            onEdit: () => setState(() => _editingName = true),
            onSave: () => _saveProfile(auth),
            onCancel: () {
              _nameCtrl.text = profile.displayName;
              setState(() => _editingName = false);
            },
          ),
          const SizedBox(height: 12),
          _InfoTile(label: 'Email', value: profile.email, icon: Icons.email_outlined),
          const SizedBox(height: 20),
          _CurrencySelector(
            selected: _selectedCurrency ?? profile.currency,
            onChanged: (c) {
              setState(() => _selectedCurrency = c);
              auth.updateProfile(profile.copyWith(currency: c));
            },
          ),
          const SizedBox(height: 20),
          _ShareSettings(profile: profile, onUpdate: (p) => auth.updateProfile(p)),
          const SizedBox(height: 28),
          const Text('Zakat Records',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kPrimaryGreen)),
          const SizedBox(height: 10),
          if (calc.records.isEmpty)
            const Center(child: Text('No submitted records yet.', style: TextStyle(color: Colors.grey)))
          else
            ...calc.records
                .where((r) => r.isSubmitted)
                .map((r) => _RecordTile(record: r, currency: profile.currency)),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final UserProfile profile;
  const _Avatar({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircleAvatar(
        radius: 44,
        backgroundColor: kPrimaryGreen.withOpacity(0.15),
        backgroundImage: profile.photoUrl != null
            ? CachedNetworkImageProvider(profile.photoUrl!)
            : null,
        child: profile.photoUrl == null
            ? Text(
                (profile.displayName.isNotEmpty ? profile.displayName[0] : '?').toUpperCase(),
                style: const TextStyle(fontSize: 36, color: kPrimaryGreen, fontWeight: FontWeight.bold),
              )
            : null,
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  final TextEditingController ctrl;
  final bool editing;
  final VoidCallback onEdit;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _NameField({
    required this.ctrl,
    required this.editing,
    required this.onEdit,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (!editing) {
      return ListTile(
        leading: const Icon(Icons.person_outline, color: kPrimaryGreen),
        title: Text(ctrl.text, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Display name'),
        trailing: IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: onEdit),
        contentPadding: EdgeInsets.zero,
      );
    }
    return Row(
      children: [
        const Icon(Icons.person_outline, color: kPrimaryGreen),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Display name'),
            autofocus: true,
          ),
        ),
        IconButton(icon: const Icon(Icons.check, color: kPrimaryGreen), onPressed: onSave),
        IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: onCancel),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoTile({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: kPrimaryGreen),
      title: Text(value),
      subtitle: Text(label),
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _CurrencySelector extends StatelessWidget {
  final String selected;
  final void Function(String) onChanged;

  const _CurrencySelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Local Currency',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: selected,
          decoration: const InputDecoration(),
          items: kCurrencies.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text('${e.key} — ${e.value}')))
              .toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ],
    );
  }
}

class _ShareSettings extends StatefulWidget {
  final UserProfile profile;
  final void Function(UserProfile) onUpdate;

  const _ShareSettings({required this.profile, required this.onUpdate});

  @override
  State<_ShareSettings> createState() => _ShareSettingsState();
}

class _ShareSettingsState extends State<_ShareSettings> {
  bool _expanded = false;
  final _emailCtrl = TextEditingController();
  late List<String> _recipients;
  late String _freq;

  @override
  void initState() {
    super.initState();
    _recipients = List.from(widget.profile.shareRecipients);
    _freq = widget.profile.shareFrequency;
  }

  void _save() {
    widget.onUpdate(widget.profile.copyWith(
      shareRecipients: _recipients,
      shareFrequency: _freq,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: const Text('Share Settings', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(_recipients.isEmpty ? 'Optional — not configured' : '${_recipients.length} recipient(s)'),
        leading: const Icon(Icons.share_outlined, color: kPrimaryGreen),
        initiallyExpanded: _expanded,
        onExpansionChanged: (v) => setState(() => _expanded = v),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Optionally share a Zakat summary with trusted people (family, advisor). '
                  'This is entirely optional and under your control.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          hintText: 'Add recipient email',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        final email = _emailCtrl.text.trim();
                        if (email.isNotEmpty && !_recipients.contains(email)) {
                          setState(() => _recipients.add(email));
                          _emailCtrl.clear();
                          _save();
                        }
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._recipients.map((e) => ListTile(
                      dense: true,
                      title: Text(e, style: const TextStyle(fontSize: 13)),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                        onPressed: () {
                          setState(() => _recipients.remove(e));
                          _save();
                        },
                      ),
                      contentPadding: EdgeInsets.zero,
                    )),
                const SizedBox(height: 8),
                const Text('Send frequency',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Wrap(
                  spacing: 8,
                  children: ['weekly', 'monthly', 'yearly'].map((f) {
                    return ChoiceChip(
                      label: Text(f[0].toUpperCase() + f.substring(1)),
                      selected: _freq == f,
                      onSelected: (_) {
                        setState(() => _freq = f);
                        _save();
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final ZakatRecord record;
  final String currency;

  const _RecordTile({required this.record, required this.currency});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: currencySymbol(currency), decimalDigits: 0);
    final dateFmt = DateFormat('d MMM yyyy');
    return Card(
      child: ListTile(
        leading: const Icon(Icons.lock_outline, color: kPrimaryGreen),
        title: Text(record.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${dateFmt.format(record.hawlStartDate)}  ·  Zakat: ${fmt.format(record.zakatDue)}'),
        trailing: record.nisabMet
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.info_outline, color: Colors.orange),
      ),
    );
  }
}
