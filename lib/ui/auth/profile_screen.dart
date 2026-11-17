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
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (auth.error != null)
            Text(l(context, auth.error!),
                style: const TextStyle(color: Colors.red)),
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(children: [
                _Avatar(profile: profile),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(profile.displayName,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(profile.email,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF63716B))),
                    ])),
                IconButton(
                    tooltip: l(context, 'Edit name'),
                    onPressed: () =>
                        setState(() => _editingName = !_editingName),
                    icon: const Icon(Icons.edit_outlined, size: 20)),
              ])),
          if (_editingName)
            _NameField(
                ctrl: _nameCtrl,
                editing: true,
                onEdit: () {},
                onSave: () => _saveProfile(auth),
                onCancel: () => setState(() {
                      _nameCtrl.text = profile.displayName;
                      _editingName = false;
                    })),
          _groupLabel(context, 'Preferences'),
          Card(
              child: Column(children: [
            Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  DropdownButtonFormField<String>(
                      value: profile.language,
                      decoration: InputDecoration(
                          labelText: l(context, 'Language / اللغة'),
                          prefixIcon: const Icon(Icons.language, size: 20)),
                      items: [
                        DropdownMenuItem(
                            value: 'en', child: Text(l(context, 'English'))),
                        const DropdownMenuItem(
                            value: 'ar', child: Text('العربية'))
                      ],
                      onChanged: (language) async {
                        if (language == null) return;
                        final ok =
                            await auth.updateProfileFields(language: language);
                        if (!context.mounted || ok) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l(context, auth.error!))));
                      }),
                  const SizedBox(height: 12),
                  SearchablePicker<String>(
                      label: l(context, 'Default currency'),
                      value: _selectedCurrency ?? profile.currency,
                      options: currencyOptions,
                      onChanged: (c) async {
                        setState(() => _selectedCurrency = c);
                        final ok = await auth.updateProfileFields(currency: c);
                        if (!mounted || !context.mounted || ok) return;
                        setState(() => _selectedCurrency = profile.currency);
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l(context, auth.error!))));
                      }),
                ])),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
                leading: const Icon(Icons.calendar_month_outlined, size: 22),
                title: Text(l(context, 'Monthly giving preferences')),
                subtitle:
                    Text(l(context, 'Default: {0} · Email reminders {1}', [
                  profile.monthlyDefaultKind == 'zakat'
                      ? l(context, 'Zakat')
                      : l(context, 'Sadaqah'),
                  profile.monthlyEmailReminders
                      ? l(context, 'on')
                      : l(context, 'off')
                ])),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const MonthlySettings())),
          ])),
          _groupLabel(context, 'Progress sharing'),
          const SharingSettingsCard(),
          _groupLabel(context, 'Account'),
          Card(
              child: Column(children: [
            ListTile(
                leading: const Icon(Icons.shield_outlined, size: 22),
                title: Text(l(context, 'Account security')),
                subtitle: Text(l(context, 'Sign-in methods and password')),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => Scaffold(
                        appBar:
                            AppBar(title: Text(l(context, 'Account security'))),
                        body: ListView(
                            padding: const EdgeInsets.all(16),
                            children: const [AccountSecurityCard()]))))),
            const Divider(height: 1, indent: 52, endIndent: 16),
            ListTile(
                leading: const Icon(Icons.delete_outline, size: 22),
                title: Text(l(context, 'Recycle bin')),
                subtitle:
                    Text(l(context, 'Restore deleted records within 60 days')),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const RecycleBinScreen()))),
            const Divider(height: 1, indent: 52, endIndent: 16),
            ListTile(
                leading: const Icon(Icons.explore_outlined, size: 22),
                title: Text(l(context, 'Getting started')),
                subtitle: Text(l(context, 'Review the welcome guide')),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const OnboardingScreen(review: true)))),
          ])),
          const AccountResetCard(),
          const SizedBox(height: 12),
          Text(
              l(context,
                  'Changing your default currency affects new records and recipients only. Existing amounts keep their original currency.'),
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF63716B), height: 1.4)),
        ],
      ),
    );
  }
}

Widget _groupLabel(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 6),
    child: Text(l(context, title),
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF63716B))));

class _Avatar extends StatelessWidget {
  final UserProfile profile;
  const _Avatar({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircleAvatar(
        radius: 28,
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
                    fontSize: 24,
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
