import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants.dart';
import '../../core/models/user_profile.dart';
import '../../core/providers/auth_provider.dart';
import 'account_security_card.dart';
import '../monthly/monthly_screen.dart';

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
    if (_nameCtrl.text.trim().isEmpty || _nameCtrl.text.trim().length > 80) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a name of up to 80 characters.')));
      return;
    }
    final ok =
        await auth.updateProfileFields(displayName: _nameCtrl.text.trim());
    if (!mounted) return;
    if (ok) setState(() => _editingName = false);
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(auth.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          TextButton(
            onPressed: auth.signOut,
            child:
                const Text('Sign out', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (auth.error != null)
            Text(auth.error!, style: const TextStyle(color: Colors.red)),
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
          _InfoTile(
              label: 'Email', value: profile.email, icon: Icons.email_outlined),
          const SizedBox(height: 20),
          const AccountSecurityCard(),
          const SizedBox(height: 20),
          _CurrencySelector(
            selected: _selectedCurrency ?? profile.currency,
            onChanged: (c) {
              setState(() => _selectedCurrency = c);
              auth.updateProfileFields(currency: c).then((ok) {
                if (!mounted || !context.mounted || ok) return;
                setState(() => _selectedCurrency = profile.currency);
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(auth.error!)));
              });
            },
          ),
          const SizedBox(height: 20),
          Card(
              child: ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Monthly giving preferences'),
            subtitle: Text(
                'Default: ${profile.monthlyDefaultKind == 'zakat' ? 'Zakat' : 'Sadaqah'} · Email reminders ${profile.monthlyEmailReminders ? 'on' : 'off'}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const MonthlySettings()),
          )),
          const SizedBox(height: 12),
          const Text(
              'Changing your default currency affects new records and recipients only. Existing amounts keep their original currency.',
              style:
                  TextStyle(fontSize: 13, color: Colors.black54, height: 1.6)),
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
                (profile.displayName.isNotEmpty ? profile.displayName[0] : '?')
                    .toUpperCase(),
                style: const TextStyle(
                    fontSize: 36,
                    color: kPrimaryGreen,
                    fontWeight: FontWeight.bold),
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
        title: Text(ctrl.text,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Display name'),
        trailing: IconButton(
            icon: const Icon(Icons.edit, size: 18), onPressed: onEdit),
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
        IconButton(
            icon: const Icon(Icons.check, color: kPrimaryGreen),
            onPressed: onSave),
        IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: onCancel),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoTile(
      {required this.label, required this.value, required this.icon});

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
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black54)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: selected,
          isExpanded: true,
          decoration: const InputDecoration(),
          items: kCurrencies.entries
              .map((e) => DropdownMenuItem(
                  value: e.key, child: Text('${e.key} — ${e.value}')))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}
