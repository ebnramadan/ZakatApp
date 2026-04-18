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
import '../tracker/tracker_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.user != null) {
        context.read<CalculatorProvider>().loadRecords(auth.user!.uid);
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
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.calculate_outlined), label: 'Calculator'),
          BottomNavigationBarItem(
              icon: Icon(Icons.track_changes_outlined), label: 'Tracker'),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Zakat')),
      body: calc.records.isEmpty
          ? _EmptyRecords()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Text('${calc.records.length} record(s)',
                        style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 8),
                ...calc.records.map(
                    (r) => _RecordCard(record: r, currency: currency)),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
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
    final fmt = NumberFormat.currency(symbol: currencySymbol(currency), decimalDigits: 0);
    final dateFmt = DateFormat('d MMM yyyy');

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: record.isSubmitted
            ? () {
                // Select this record in tracker and navigate to it
                final auth = context.read<AuthProvider>();
                context.read<TrackerProvider>().selectRecord(auth.user!.uid, record);
                DefaultTabController.of(context);
                // Navigate to tracker tab via home
                final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                homeState?.setState(() => homeState._tab = 1);
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
                      'Hawl: ${dateFmt.format(record.hawlStartDate)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    if (record.isSubmitted) ...[
                      const SizedBox(height: 2),
                      Text(
                        record.nisabMet
                            ? 'Zakat due: ${fmt.format(record.zakatDue)}'
                            : 'Below Nisab — no Zakat due',
                        style: TextStyle(
                          fontSize: 12,
                          color: record.nisabMet ? kPrimaryGreen : Colors.orange,
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
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const EntryModeScreen())),
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
              'Start your first Zakat calculation.\nMay Allah accept it.',
              style: TextStyle(color: Colors.grey, height: 1.6),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
