import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../utils/currency_formatter.dart';
import '../widgets/amount_field.dart';

/// Default admin fees per dompet pair (e.g. Bank -> OVO always costs
/// Rp1.000, Saldo Grab -> Bank costs Rp500) — Transfer looks one up
/// automatically for whichever two dompets are selected there.
class AdminFeeScreen extends StatelessWidget {
  const AdminFeeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final routes = walletProvider.configuredAdminFees;

    return Scaffold(
      appBar: AppBar(title: const Text('Biaya Admin Transfer')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editRoute(context, walletProvider),
        child: const Icon(Icons.add),
      ),
      body: routes.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Belum ada biaya admin default. Tambahkan per pasangan dompet (misalnya Bank ke OVO) supaya otomatis terisi tiap kali Transfer dibuka untuk pasangan itu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: routes.map((r) {
                final fromName = walletProvider.byId(r.$1)?.name ?? r.$1;
                final toName = walletProvider.byId(r.$2)?.name ?? r.$2;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const Icon(Icons.call_made),
                    title: Text('$fromName → $toName'),
                    subtitle: Text('Rp${formatPlainThousands(r.$3)} / transfer'),
                    trailing: IconButton(
                      tooltip: 'Hapus',
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => walletProvider.setAdminFeeFor(r.$1, r.$2, 0),
                    ),
                    onTap: () => _editRoute(context, walletProvider, existing: r),
                  ),
                );
              }).toList(),
            ),
    );
  }

  void _editRoute(
    BuildContext context,
    WalletProvider walletProvider, {
    (String, String, double)? existing,
  }) {
    final wallets = walletProvider.wallets;
    if (wallets.isEmpty) return;
    var fromId = existing?.$1 ?? wallets.first.id;
    var toId = existing?.$2 ?? (wallets.length > 1 ? wallets[1].id : wallets.first.id);
    final ctrl = TextEditingController(text: existing != null ? formatPlainThousands(existing.$3) : '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text(existing == null ? 'Tambah Biaya Admin' : 'Ubah Biaya Admin'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dari Dompet', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: wallets.any((w) => w.id == fromId) ? fromId : null,
                  items: wallets.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                  onChanged: (v) => setState(() => fromId = v ?? fromId),
                ),
                const SizedBox(height: 14),
                const Text('Ke Dompet', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: wallets.any((w) => w.id == toId) ? toId : null,
                  items: wallets.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                  onChanged: (v) => setState(() => toId = v ?? toId),
                ),
                const SizedBox(height: 14),
                AmountField(controller: ctrl, label: 'Biaya Admin'),
                if (fromId == toId)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Dari dan Ke Dompet tidak boleh sama.',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              FilledButton(
                onPressed: fromId == toId
                    ? null
                    : () {
                        final value = parseFormattedAmount(ctrl.text);
                        walletProvider.setAdminFeeFor(fromId, toId, value);
                        Navigator.pop(ctx);
                      },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }
}
