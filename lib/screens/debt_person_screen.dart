import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/debt_model.dart';
import '../providers/asset_provider.dart';
import '../providers/finance_provider.dart';
import '../utils/currency_formatter.dart';
import '../widgets/debt_tile.dart';
import 'debt_entry_screen.dart';

/// All debt records for one person, grouped together instead of showing
/// as separate bubbles in the Transaksi tab.
class DebtPersonScreen extends StatelessWidget {
  final String personName;

  const DebtPersonScreen({super.key, required this.personName});

  @override
  Widget build(BuildContext context) {
    final assetProvider = context.watch<AssetProvider>();
    final financeProvider = context.read<FinanceProvider>();
    final entries = assetProvider.debtsForPerson(personName);
    final colorScheme = Theme.of(context).colorScheme;

    final receivable = entries
        .where((d) => !d.isPaid && d.direction == DebtDirection.theyOweMe)
        .fold(0.0, (s, d) => s + d.remaining);
    final payable = entries
        .where((d) => !d.isPaid && d.direction == DebtDirection.iOweThem)
        .fold(0.0, (s, d) => s + d.remaining);

    return Scaffold(
      appBar: AppBar(title: Text(personName)),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_debt_person',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DebtEntryScreen(initialName: personName)),
        ),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          if (receivable > 0)
            _summaryLine(context, 'Piutang ke $personName', receivable, Colors.green.shade700),
          if (payable > 0)
            _summaryLine(context, 'Utang ke $personName', payable, Colors.red.shade700),
          if (receivable == 0 && payable == 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Semua sudah lunas', style: TextStyle(color: colorScheme.onSurfaceVariant)),
            ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: entries
                  .map((d) => DebtTile(debt: d, onTap: () => showDebtActions(context, assetProvider, financeProvider, d)))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryLine(BuildContext context, String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(formatRupiah(value), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
