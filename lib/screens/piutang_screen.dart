import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/debt_model.dart';
import '../providers/asset_provider.dart';
import '../providers/finance_provider.dart';
import '../utils/currency_formatter.dart';
import '../widgets/gradient_stat_card.dart';
import 'debt_entry_screen.dart';
import 'debt_person_screen.dart';

class PiutangScreen extends StatefulWidget {
  const PiutangScreen({super.key});

  @override
  State<PiutangScreen> createState() => _PiutangScreenState();
}

class _PiutangScreenState extends State<PiutangScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  /// Which side of utang/piutang this screen is currently showing —
  /// toggled with the segmented control below the search bar.
  DebtDirection _direction = DebtDirection.theyOweMe;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assetProvider = context.watch<AssetProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final isPiutang = _direction == DebtDirection.theyOweMe;

    final total = isPiutang ? assetProvider.totalReceivable : assetProvider.totalPayable;
    // Only people with something still unpaid on the selected side show up
    // here. Once it's fully paid off, they move to Riwayat — reachable
    // from the app bar — instead of cluttering this list.
    var people = assetProvider.debtsByPerson
        .where((p) => isPiutang ? p.unpaidReceivable > 0 : p.unpaidPayable > 0)
        .toList();
    if (_query.isNotEmpty) {
      people = people.where((p) => p.personName.toLowerCase().contains(_query)).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isPiutang ? 'Piutang' : 'Utang'),
        actions: [
          IconButton(
            tooltip: 'Riwayat',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PiutangRiwayatScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_piutang',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DebtEntryScreen(initialDirection: _direction)),
        ),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Cari dari nama...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _searchCtrl.clear();
                        _query = '';
                      }),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<DebtDirection>(
            segments: const [
              ButtonSegment(value: DebtDirection.theyOweMe, label: Text('Piutang'), icon: Icon(Icons.call_received)),
              ButtonSegment(value: DebtDirection.iOweThem, label: Text('Utang'), icon: Icon(Icons.call_made)),
            ],
            selected: {_direction},
            onSelectionChanged: (s) => setState(() => _direction = s.first),
          ),
          const SizedBox(height: 16),
          GradientStatCard(
            title: isPiutang ? 'Piutang' : 'Utang',
            mainValue: total,
            stats: const [],
          ),
          const SizedBox(height: 20),
          if (people.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  _query.isNotEmpty
                      ? 'Tidak ada nama yang cocok'
                      : (isPiutang ? 'Belum ada piutang' : 'Belum ada utang'),
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: people
                    .map((p) => _PersonBubble(
                          summary: p,
                          direction: _direction,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => DebtPersonScreen(personName: p.personName)),
                          ),
                          onDelete: () => confirmDeletePerson(context, assetProvider, p.personName),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

/// Everyone who doesn't show up in the focused Piutang list anymore —
/// their piutang is fully paid off (or they only ever had utang records).
class PiutangRiwayatScreen extends StatefulWidget {
  const PiutangRiwayatScreen({super.key});

  @override
  State<PiutangRiwayatScreen> createState() => _PiutangRiwayatScreenState();
}

class _PiutangRiwayatScreenState extends State<PiutangRiwayatScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final assetProvider = context.watch<AssetProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    var people = assetProvider.debtsByPerson.where((p) => p.unpaidReceivable <= 0).toList();
    if (_query.isNotEmpty) {
      people = people.where((p) => p.personName.toLowerCase().contains(_query)).toList();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Piutang')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Cari dari nama...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _searchCtrl.clear();
                        _query = '';
                      }),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (people.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  _query.isEmpty ? 'Belum ada riwayat' : 'Tidak ada nama yang cocok',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: people
                    .map((p) => _PersonBubble(
                          summary: p,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => DebtPersonScreen(personName: p.personName)),
                          ),
                          onDelete: () => confirmDeletePerson(context, assetProvider, p.personName),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

void confirmDeletePerson(BuildContext context, AssetProvider provider, String personName) {
  final financeProvider = context.read<FinanceProvider>();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Hapus Data'),
      content: Text('Semua riwayat utang/piutang untuk "$personName" (termasuk transaksi pelunasannya) akan dihapus.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        TextButton(
          onPressed: () {
            provider.deletePersonDebts(personName, financeProvider);
            Navigator.pop(ctx);
          },
          child: const Text('Hapus', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

/// One bubble per person, combining all of their debt records so the
/// list doesn't repeat the same name over and over.
class _PersonBubble extends StatelessWidget {
  final DebtPersonSummary summary;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  /// On the focused Piutang/Utang list, every person shown already has a
  /// balance on this specific side — so the bubble reads just that side,
  /// ignoring any separate balance they might have on the other one. Null
  /// (used on Riwayat, which mixes both) falls back to the combined net.
  final DebtDirection? direction;

  const _PersonBubble({required this.summary, required this.onTap, required this.onDelete, this.direction});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final net = switch (direction) {
      DebtDirection.theyOweMe => summary.unpaidReceivable,
      DebtDirection.iOweThem => -summary.unpaidPayable,
      null => summary.net,
    };
    final initial = summary.personName.isNotEmpty ? summary.personName[0].toUpperCase() : '?';

    String trailingText;
    Color trailingColor;
    if (net > 0) {
      trailingText = formatRupiah(net);
      trailingColor = Colors.green.shade700;
    } else if (net < 0) {
      trailingText = formatRupiah(net.abs());
      trailingColor = Colors.red.shade700;
    } else {
      trailingText = 'Lunas';
      trailingColor = colorScheme.onSurfaceVariant;
    }

    final subtitle = summary.entries.length == 1 ? '1 transaksi' : '${summary.entries.length} transaksi';

    return Dismissible(
      key: ValueKey(summary.personName),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: Colors.red.shade400,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Text(initial, style: TextStyle(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold)),
        ),
        title: Text(summary.personName),
        subtitle: Text(subtitle),
        trailing: Text(trailingText, style: TextStyle(color: trailingColor, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
