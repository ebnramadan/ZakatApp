import '../../core/localization/strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants.dart';
import '../../core/models/user_profile.dart';
import '../../core/providers/auth_provider.dart';
import 'account_security_card.dart';
import '../monthly/monthly_screen.dart';
import '../home/recycle_bin_screen.dart';
import '../widgets/searchable_picker.dart';
import 'account_reset_card.dart';
import '../onboarding/onboarding_screen.dart';
import 'sharing_settings_card.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l(context, "Enter a name of up to 80 characters."))));
      return;
    }
    final ok =
        await auth.updateProfileFields(displayName: _nameCtrl.text.trim());
    if (!mounted) return;
    if (ok) setState(() => _editingName = false);
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l(context, auth.error!))));
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
        title: Text(l(context, "Profile")),
        actions: [
          TextButton(
            onPressed: auth.signOut,
            child: Text(l(context, "Sign out"),
                style: const TextStyle(color: kPrimaryGreen)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (auth.error != null)
            Text(l(context, auth.error!),
                style: const TextStyle(color: Colors.red)),
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
              label: l(context, "Email"),
              value: profile.email,
              icon: Icons.email_outlined),
          const SizedBox(height: 20),
          const AccountSecurityCard(),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: profile.language,
            decoration: InputDecoration(
                labelText: l(context, "Language / اللغة"),
                prefixIcon: const Icon(Icons.language)),
            items: [
              DropdownMenuItem(value: 'en', child: Text(l(context, "English"))),
              const DropdownMenuItem(value: 'ar', child: Text('العربية')),
            ],
            onChanged: (language) async {
              if (language == null) return;
              final ok = await auth.updateProfileFields(language: language);
              if (!context.mounted || ok) return;
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l(context, auth.error!))));
            },
          ),
          const SizedBox(height: 20),
          _CurrencySelector(
            selected: _selectedCurrency ?? profile.currency,
            onChanged: (c) {
              setState(() => _selectedCurrency = c);
              auth.updateProfileFields(currency: c).then((ok) {
                if (!mounted || !context.mounted || ok) return;
                setState(() => _selectedCurrency = profile.currency);
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l(context, auth.error!))));
              });
            },
          ),
          const SizedBox(height: 20),
          Card(
              child: ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: Text(l(context, "Monthly giving preferences")),
            subtitle: Text(l(context, "Default: {0} · Email reminders {1}", [
              profile.monthlyDefaultKind == 'zakat'
                  ? l(context, "Zakat")
                  : l(context, "Sadaqah"),
              profile.monthlyEmailReminders
                  ? l(context, 'on')
                  : l(context, 'off')
            ])),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const MonthlySettings()),
          )),
          const SizedBox(height: 12),
          Card(
              child: ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(l(context, "Recycle bin")),
                  subtitle: Text(
                      l(context, "Restore deleted records within 60 days")),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const RecycleBinScreen())))),
          const SizedBox(height: 12),
          const SharingSettingsCard(),
          Card(
              child: ListTile(
                  leading: const Icon(Icons.explore_outlined),
                  title: Text(l(context, "Getting started")),
                  subtitle: Text(l(context, "Review the welcome guide")),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const OnboardingScreen(review: true))))),
          const AccountResetCard(),
          const SizedBox(height: 12),
          Text(
              l(context,
                  "Changing your default currency affects new records and recipients only. Existing amounts keep their original currency."),
              style: const TextStyle(
                  fontSize: 13, color: Colors.black54, height: 1.6)),
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
                l(
                    context,
                    (profile.displayName.isNotEmpty
                            ? profile.displayName[0]
                            : '?')
                        .toUpperCase()),
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
        title: Text(l(context, ctrl.text),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(l(context, "Display name")),
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
            decoration: InputDecoration(labelText: l(context, "Display name")),
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
      title: Text(l(context, value)),
      subtitle: Text(l(context, label)),
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
        Text(l(context, "Local Currency"),
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black54)),
        const SizedBox(height: 8),
        SearchablePicker<String>(
            label: l(context, "Default currency"),
            value: selected,
            options: currencyOptions,
            onChanged: onChanged),
      ],
    );
  }
}
