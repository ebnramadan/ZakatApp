import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/models/zakat_record.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/calculator_provider.dart';
import '../../core/providers/tracker_provider.dart';
import '../../core/providers/monthly_provider.dart';
import '../auth/profile_screen.dart';
import '../calculator/entry_mode_screen.dart';
import '../calculator/one_pager_screen.dart';
import '../tracker/tracker_screen.dart';
import '../monthly/monthly_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../shared/app_components.dart';
import 'recycle_bin_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialTab;
  const HomeScreen({super.key, this.initialTab = 0});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _tab;
  void _selectTab(int index) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _tab = index);
  }

  void openTracker() => _selectTab(2);
  void openMonthly() => _selectTab(3);
  void _create() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const EntryModeScreen()));
  void _open(ZakatRecord r) {
    if (r.isSubmitted) {
      context
          .read<TrackerProvider>()
          .selectRecord(context.read<AuthProvider>().user!.uid, r);
      openTracker();
    } else {
      context.read<CalculatorProvider>().resumeRecord(r);
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const OnePagerScreen()));
    }
  }

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<AuthProvider>().user?.uid;
      if (uid != null) {
        context.read<CalculatorProvider>().loadRecords(uid);
        context.read<MonthlyProvider>().load(uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final calc = context.watch<CalculatorProvider>();
    final monthly = context.watch<MonthlyProvider>();
    final now = DateTime.now();
    final due = monthly.loading
        ? 0
        : monthly.plans
            .where((p) =>
                p.active &&
                (p.kind != 'zakat' || calc.isRecordActive(p.zakatRecordId)) &&
                p.startMonth.compareTo(
                        '${now.year}-${now.month.toString().padLeft(2, '0')}') <=
                    0 &&
                !p
                    .dueDate(
                        '${now.year}-${now.month.toString().padLeft(2, '0')}')
                    .isAfter(now) &&
                monthly.paid(p.id,
                        '${now.year}-${now.month.toString().padLeft(2, '0')}') ==
                    null)
            .length;
    final ar = auth.profile?.language == 'ar';
    final labels = [
      ar ? 'الرئيسية' : 'Dashboard',
      ar ? 'السجلات' : 'Records',
      ar ? 'المتابعة' : 'Tracker',
      auth.profile?.monthlyGivingLabel ?? 'Monthly Giving',
      ar ? 'الملف الشخصي' : 'Profile'
    ];
    const icons = [
      Icons.space_dashboard_outlined,
      Icons.folder_open_outlined,
      Icons.track_changes_outlined,
      Icons.calendar_month_outlined,
      Icons.person_outline
    ];
    final body = IndexedStack(index: _tab, children: [
      DashboardScreen(
          onRecords: () => _selectTab(1),
          onMonthly: openMonthly,
          onCreate: _create,
          onRecord: _open),
      _RecordsTab(onCreate: _create, onOpen: _open),
      TrackerScreen(onOpenMonthly: openMonthly),
      const MonthlyScreen(),
      const ProfileScreen(),
    ]);
    Widget navIcon(int index) => index == 3
        ? Badge(
            isLabelVisible: due > 0,
            label: Text('$due'),
            child: Icon(icons[index]))
        : Icon(icons[index]);
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      return Scaffold(
        body: wide
            ? Row(children: [
                Container(
                    width: 208,
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                            right: BorderSide(color: Color(0xFFDDE5E1)))),
                    child: SafeArea(
                        child: Column(children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                          child: Row(children: [
                            Image.asset('assets/brand/icon.png',
                                width: 36, height: 36),
                            const SizedBox(width: 10),
                            const Expanded(
                                child: Text('Zakat Tracker',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)))
                          ])),
                      Expanded(
                          child: NavigationRail(
                              extended: true,
                              minExtendedWidth: 207,
                              selectedIndex: _tab,
                              onDestinationSelected: (i) =>
                                  setState(() => _tab = i),
                              backgroundColor: Colors.white,
                              destinations: List.generate(
                                  5,
                                  (i) => NavigationRailDestination(
                                      icon: navIcon(i),
                                      label: Text(labels[i]))))),
                      const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                              'Give with intention.\nTrack with clarity.',
                              style: TextStyle(
                                  color: Color(0xFF52655F),
                                  fontSize: 12,
                                  height: 1.7))),
                    ]))),
                Expanded(child: body),
              ])
            : body,
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: _selectTab,
                destinations: List.generate(
                    5,
                    (i) => NavigationDestination(
                        icon: navIcon(i), label: labels[i]))),
      );
    });
  }
}

class _RecordsTab extends StatefulWidget {
  final VoidCallback onCreate;
  final ValueChanged<ZakatRecord> onOpen;
  const _RecordsTab({required this.onCreate, required this.onOpen});
  @override
  State<_RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<_RecordsTab> {
  String _query = '';
  String _filter = 'All';
  @override
  Widget build(BuildContext context) {
    final calc = context.watch<CalculatorProvider>();
    final records = calc.records
        .where((r) =>
            r.name.toLowerCase().contains(_query.toLowerCase()) &&
            (_filter == 'All' ||
                (_filter == 'Drafts' ? !r.isSubmitted : r.isSubmitted)))
        .toList();
    return SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
      PageIntro(
          eyebrow: 'Zakat records',
          title: 'A place for every year.',
          description:
              'Calculate once. Keep your records and payment history together.',
          action: Wrap(spacing: 12, runSpacing: 12, children: [
            FilledButton.icon(
                onPressed: widget.onCreate,
                icon: const Icon(Icons.add),
                label: const Text('New Calculation')),
            OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const RecycleBinScreen())),
                icon: const Icon(Icons.delete_outline),
                label: Text(
                    'Recycle bin${calc.recycledRecords.isEmpty ? '' : ' (${calc.recycledRecords.length})'}')),
          ])),
      if (calc.error != null)
        Card(
            child: ListTile(
                leading: const Icon(Icons.error_outline),
                title: Text(calc.error!),
                trailing: TextButton(
                    onPressed: calc.clearError, child: const Text('Dismiss')))),
      if (calc.recordsLoading)
        const Center(child: CircularProgressIndicator())
      else if (calc.records.isEmpty)
        Card(
            child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(children: [
                  const Icon(Icons.folder_open_outlined,
                      size: 48, color: kPrimaryGreen),
                  const SizedBox(height: 16),
                  Text('Your first record starts here',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text(
                      'Use a guided calculation to work out your Zakat. Saved drafts are easy to continue.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  TextButton(
                      onPressed: widget.onCreate,
                      child: const Text('Create a Zakat record')),
                ])))
      else ...[
        TextField(
            decoration: const InputDecoration(
                labelText: 'Search records', prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 16),
        Wrap(
            spacing: 8,
            children: ['All', 'Submitted', 'Drafts']
                .map((v) => ChoiceChip(
                    label: Text(v),
                    selected: v == _filter,
                    onSelected: (_) => setState(() => _filter = v)))
                .toList()),
        const SizedBox(height: 16),
        if (records.isEmpty)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No records match. Try another search or filter.')),
        ...records.map((r) => Card(
            child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(r.name,
                                style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700))),
                        PopupMenuButton<String>(
                            tooltip: 'Record actions',
                            onSelected: (_) => moveToRecycleBin(context, r),
                            itemBuilder: (_) => [
                                  const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Move to recycle bin',
                                          style: TextStyle(
                                              color: Color(0xFFB3261E))))
                                ])
                      ]),
                      const SizedBox(height: 8),
                      StatusPill(
                          r.isSubmitted
                              ? (r.hawlComplete
                                  ? 'Hawl complete'
                                  : 'Hawl in progress')
                              : 'Draft',
                          warning: !r.isSubmitted),
                      const SizedBox(height: 12),
                      Text(
                          'Lunar year started ${DateFormat.yMMMd().format(r.hawlStartDate)}',
                          style: const TextStyle(
                              color: Color(0xFF52655F), fontSize: 13)),
                      if (r.isSubmitted) ...[
                        const SizedBox(height: 12),
                        Text(
                            r.nisabMet
                                ? money(r.estimatedZakat, r.currency)
                                : 'Below Nisab',
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: kPrimaryGreen)),
                        Text(
                            r.hawlComplete
                                ? 'Calculated Zakat'
                                : 'Estimate until Hawl is complete',
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF52655F)))
                      ],
                      const SizedBox(height: 12),
                      TextButton.icon(
                          onPressed: () => widget.onOpen(r),
                          icon: Icon(r.isSubmitted
                              ? Icons.arrow_forward
                              : Icons.edit_outlined),
                          label: Text(r.isSubmitted
                              ? 'Open payment tracker'
                              : 'Continue draft')),
                    ])))),
      ],
    ]));
  }
}
