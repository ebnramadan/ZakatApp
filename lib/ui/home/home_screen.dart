import '../../core/localization/strings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/models/zakat_record.dart';
import '../../core/models/monthly_giving.dart';
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
  String? _monthlyFocus;
  void _selectTab(int index) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _tab = index);
  }

  void openTracker() => _selectTab(2);
  void openMonthly() {
    setState(() => _monthlyFocus = null);
    _selectTab(3);
  }

  void _openCommitment(MonthlyPlan plan) {
    setState(() => _monthlyFocus = plan.recipient);
    _selectTab(3);
  }

  void _create() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const EntryModeScreen()));
  void _open(ZakatRecord r) {
    final auth = context.read<AuthProvider>();
    auth.updateProfileFields(defaultRecordId: r.id).then((ok) {
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l(
                context, auth.error ?? 'Default record could not be saved.'))));
      }
    });
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
    final current = calc.defaultRecord(auth.profile?.defaultRecordId);
    if (!calc.recordsLoading &&
        current != null &&
        current.id != auth.profile?.defaultRecordId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            context.read<AuthProvider>().profile?.defaultRecordId !=
                current.id) {
          context
              .read<AuthProvider>()
              .updateProfileFields(defaultRecordId: current.id);
        }
      });
    }
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
    final mobileLabels = [
      labels[0],
      labels[1],
      labels[2],
      ar ? 'شهريات' : 'Monthly',
      ar ? 'حسابي' : 'Profile'
    ];
    const selectedIcons = [
      Icons.space_dashboard_rounded,
      Icons.folder_rounded,
      Icons.track_changes_rounded,
      Icons.calendar_month_rounded,
      Icons.person_rounded
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
          onCommitment: _openCommitment,
          onCreate: _create,
          onRecord: _open),
      _RecordsTab(onCreate: _create, onOpen: _open),
      TrackerScreen(
          onOpenMonthly: openMonthly, onOpenRecords: () => _selectTab(1)),
      MonthlyScreen(
          key: ValueKey(_monthlyFocus), focusRecipient: _monthlyFocus),
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
                    width: 232,
                    decoration: const BoxDecoration(
                        color: Color(0xFF103F36),
                        border: BorderDirectional(
                            end: BorderSide(color: Color(0xFFDDE5E1)))),
                    child: SafeArea(
                        child: Column(children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
                          child: Row(children: [
                            Image.asset('assets/brand/icon.png',
                                width: 36, height: 36),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(l(context, "Zakat Tracker"),
                                    style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700)))
                          ])),
                      Expanded(
                          child: NavigationRail(
                              extended: true,
                              minExtendedWidth: 231,
                              selectedIndex: _tab,
                              onDestinationSelected: (i) =>
                                  setState(() => _tab = i),
                              backgroundColor: const Color(0xFF103F36),
                              selectedIconTheme:
                                  const IconThemeData(color: Color(0xFFE9C77B)),
                              unselectedIconTheme:
                                  const IconThemeData(color: Color(0xFFCBDFD5)),
                              selectedLabelTextStyle: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700),
                              unselectedLabelTextStyle:
                                  const TextStyle(color: Color(0xFFCBDFD5)),
                              destinations: List.generate(
                                  5,
                                  (i) => NavigationRailDestination(
                                      icon: navIcon(i),
                                      label: Text(l(context, labels[i])))))),
                      Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                              l(context,
                                  "Give with intention.\nTrack with clarity."),
                              style: const TextStyle(
                                  color: Color(0xFFCBDFD5),
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
                        icon: navIcon(i),
                        selectedIcon: Icon(selectedIcons[i]),
                        label: mobileLabels[i]))),
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
    final defaultId = calc
        .defaultRecord(context.watch<AuthProvider>().profile?.defaultRecordId)
        ?.id;
    final records = calc.records
        .where((r) =>
            r.id != defaultId &&
            r.name.toLowerCase().contains(_query.toLowerCase()) &&
            (_filter == 'All' ||
                (_filter == 'Drafts' ? !r.isSubmitted : r.isSubmitted)))
        .toList()
      ..sort((a, b) => a.id == defaultId
          ? -1
          : b.id == defaultId
              ? 1
              : b.createdAt.compareTo(a.createdAt));
    Widget recordCard(ZakatRecord r) => Card(
        color: r.id == defaultId ? const Color(0xFFE8F2EC) : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
                color:
                    r.id == defaultId ? kPrimaryGreen : const Color(0xFFDDE5E1),
                width: r.id == defaultId ? 2 : 1)),
        child: Padding(
            padding: const EdgeInsets.all(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(r.name,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w700))),
                const SizedBox.shrink()
              ]),
              if (calc
                      .defaultRecord(context
                          .watch<AuthProvider>()
                          .profile
                          ?.defaultRecordId)
                      ?.id ==
                  r.id)
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: StatusPill(l(context, "Default record"))),
              const SizedBox(height: 8),
              StatusPill(
                  r.isSubmitted
                      ? l(
                          context,
                          (r.hawlComplete
                              ? 'Hawl complete'
                              : 'Hawl in progress'))
                      : l(context, "Draft"),
                  warning: !r.isSubmitted),
              const SizedBox(height: 12),
              Text(
                  l(context, "Lunar year started {0}",
                      [DateFormat.yMMMd().format(r.hawlStartDate)]),
                  style:
                      const TextStyle(color: Color(0xFF52655F), fontSize: 13)),
              if (r.isSubmitted) ...[
                const SizedBox(height: 12),
                Text(
                    r.nisabMet
                        ? l(context, money(r.estimatedZakat, r.currency))
                        : l(context, "Below Nisab"),
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: kPrimaryGreen)),
                Text(
                    r.hawlComplete
                        ? l(context, "Calculated Zakat")
                        : l(context, "Estimate until Hawl is complete"),
                    style:
                        const TextStyle(fontSize: 13, color: Color(0xFF52655F)))
              ],
              const SizedBox(height: 12),
              if (context.watch<AuthProvider>().profile?.defaultRecordId !=
                  r.id)
                TextButton.icon(
                    onPressed: () async {
                      final auth = context.read<AuthProvider>();
                      final ok =
                          await auth.updateProfileFields(defaultRecordId: r.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(ok
                                ? l(context, "Default record updated.")
                                : l(context, auth.error!))));
                      }
                    },
                    icon: const Icon(Icons.star_outline),
                    label: Text(l(context, "Set as default"))),
              TextButton.icon(
                  onPressed: () => widget.onOpen(r),
                  icon: Icon(r.isSubmitted
                      ? Icons.arrow_forward
                      : Icons.edit_outlined),
                  label: Text(r.isSubmitted
                      ? l(context, "Open payment tracker")
                      : l(context, "Continue draft"))),
              TextButton.icon(
                  onPressed: () => moveToRecycleBin(context, r),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(r.id == defaultId
                      ? l(context, "Delete default record")
                      : l(context, "Delete record")),
                  style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFB3261E)))
            ])));
    return SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
      PageIntro(
          eyebrow: l(context, "Zakat records"),
          title: l(context, "A place for every year."),
          description: l(context,
              "Calculate once. Keep your records and payment history together."),
          action: Wrap(spacing: 12, runSpacing: 12, children: [
            FilledButton.icon(
                onPressed: widget.onCreate,
                icon: const Icon(Icons.add),
                label: Text(l(context, "New Calculation"))),
            OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const RecycleBinScreen())),
                icon: const Icon(Icons.delete_outline),
                label: Text(l(context, "Recycle bin{0}", [
                  calc.recycledRecords.isEmpty
                      ? ''
                      : ' (${calc.recycledRecords.length})'
                ]))),
          ])),
      if (calc.recordsError != null)
        Card(
            child: ListTile(
                leading: const Icon(Icons.error_outline),
                title: Text(l(context, calc.recordsError!)),
                trailing: TextButton(
                    onPressed: () => calc
                        .loadRecords(context.read<AuthProvider>().user!.uid),
                    child: Text(l(context, "Retry"))))),
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
                  Text(l(context, "Your first record starts here"),
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                      l(context,
                          "Use a guided calculation to work out your Zakat. Saved drafts are easy to continue."),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  TextButton(
                      onPressed: widget.onCreate,
                      child: Text(l(context, "Create a Zakat record"))),
                ])))
      else ...[
        if (defaultId != null)
          recordCard(calc.records.firstWhere((r) => r.id == defaultId)),
        SectionTitle(l(context, 'Other records')),
        TextField(
            decoration: InputDecoration(
                labelText: l(context, "Search records"),
                prefixIcon: const Icon(Icons.search)),
            onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 16),
        Wrap(
            spacing: 8,
            children: ['All', 'Submitted', 'Drafts']
                .map((v) => ChoiceChip(
                    label: Text(l(context, v)),
                    selected: v == _filter,
                    onSelected: (_) => setState(() => _filter = v)))
                .toList()),
        const SizedBox(height: 16),
        if (records.isEmpty)
          Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l(
                  context,
                  _query.isEmpty && _filter == 'All'
                      ? 'No other records yet.'
                      : 'No records match. Try another search or filter.'))),
        ...records.map(recordCard),
      ],
    ]));
  }
}
