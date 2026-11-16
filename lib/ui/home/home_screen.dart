import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/models/zakat_record.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/calculator_provider.dart';
import '../../core/providers/tracker_provider.dart';
import '../auth/profile_screen.dart';
import '../calculator/entry_mode_screen.dart';
import '../calculator/one_pager_screen.dart';
import '../tracker/tracker_screen.dart';
import '../monthly/monthly_screen.dart';
import '../../core/providers/monthly_provider.dart';

class HomeScreen extends StatefulWidget {
  final int initialTab;
  const HomeScreen({super.key, this.initialTab = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _tab;

  void openTracker() => setState(() => _tab = 1);
  void openMonthly() => setState(() => _tab = 2);

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (auth.user != null) {
        context.read<CalculatorProvider>().loadRecords(auth.user!.uid);
        context.read<MonthlyProvider>().load(auth.user!.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          _RecordsTab(),
          TrackerScreen(),
          MonthlyScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.calculate_outlined), label: 'Calculator'),
          BottomNavigationBarItem(
              icon: Icon(Icons.track_changes_outlined), label: 'Tracker'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined), label: 'شهريات'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Records tab: list of Zakat records + new calculation button
// ─────────────────────────────────────────────────────────────────────────────
class _RecordsTab extends StatelessWidget {
  const _RecordsTab();

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final calc = context.watch<CalculatorProvider>();
    final currency = auth.profile?.currency ?? 'USD';
    final due = context.watch<MonthlyProvider>().dueCount(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Zakat Tracker')),
      body: calc.error != null
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(calc.error!, textAlign: TextAlign.center),
              TextButton(
                  onPressed: () {
                    calc.clearError();
                    calc.loadRecords(auth.user!.uid);
                  },
                  child: const Text('Retry')),
            ]))
          : calc.records.isEmpty
              ? _EmptyRecords()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (due > 0)
                      Card(
                          color:
                              Theme.of(context).colorScheme.secondaryContainer,
                          child: ListTile(
                              leading: const Icon(
                                  Icons.notifications_active_outlined),
                              title: Text(
                                  '$due monthly ${due == 1 ? 'commitment is' : 'commitments are'} ready to give'),
                              subtitle: const Text(
                                  'Review this month’s giving in شهريات'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context
                                  .findAncestorStateOfType<_HomeScreenState>()
                                  ?.openMonthly())),
                    Text('Your Zakat records',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    const Text(
                        'Continue a draft or open a submitted record to track payments.',
                        style: TextStyle(height: 1.5, color: Colors.black54)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text('${calc.records.length} record(s)',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13)),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...calc.records
                        .map((r) => _RecordCard(record: r, currency: currency)),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-calculation',
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const EntryModeScreen())),
        icon: const Icon(Icons.add),
        label: const Text('New Calculation'),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final ZakatRecord record;
  final String currency;

  const _RecordCard({required this.record, required this.currency});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(
        symbol: record.currency == null
            ? 'Currency unknown '
            : currencySymbol(record.currency!),
        decimalDigits: 2);
    final dateFmt = DateFormat('d MMM yyyy');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: record.isSubmitted
            ? () {
                // Select this record in tracker and navigate to it
                final auth = context.read<AuthProvider>();
                context
                    .read<TrackerProvider>()
                    .selectRecord(auth.user!.uid, record);

                // Navigate to tracker tab via home
                final homeState =
                    context.findAncestorStateOfType<_HomeScreenState>();
                homeState?.openTracker();
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: record.isSubmitted
                      ? kPrimaryGreen.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  record.isSubmitted ? Icons.lock_outline : Icons.edit_outlined,
                  color: record.isSubmitted ? kPrimaryGreen : Colors.orange,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      'Lunar year started ${dateFmt.format(record.hawlStartDate)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    if (record.isSubmitted) ...[
                      const SizedBox(height: 2),
                      Text(
                        record.nisabMet
                            ? '${record.hawlComplete ? 'Zakat due' : 'Estimate'}: ${fmt.format(record.estimatedZakat)}'
                            : 'Below Nisab — no Zakat due',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              record.nisabMet ? kPrimaryGreen : Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (record.isSubmitted)
                const Icon(Icons.chevron_right, color: Colors.grey)
              else
                TextButton(
                  onPressed: () {
                    context.read<CalculatorProvider>().resumeRecord(record);
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const OnePagerScreen()));
                  },
                  child: const Text('Continue'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyRecords extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: kPrimaryGreen.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mosque, size: 56, color: kPrimaryGreen),
            ),
            const SizedBox(height: 24),
            const Text(
              'Bismillah',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: kPrimaryGreen),
            ),
            const SizedBox(height: 8),
            const Text(
              'Calculate your eligible wealth, then track what you give. You can also start with monthly giving in شهريات.',
              style: TextStyle(color: Colors.grey, height: 1.6),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
