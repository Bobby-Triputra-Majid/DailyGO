import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/wallet_model.dart';
import '../providers/finance_provider.dart';
import '../providers/wallet_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/grouping.dart';
import '../widgets/transaction_tile.dart';
import 'wallet_transfer_screen.dart';

/// Lists every dompet and its balance, with a generic manual transfer
/// between any two dompets (also used for "Tarik Saldo Grab", by picking
/// Saldo Grab -> Bank in the transfer form). Tapping a wallet shows its
/// own transaction history.
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    // Rebuild balances whenever FinanceProvider changes too (a new
    // transaction, edit, or delete affects wallet totals).
    context.watch<FinanceProvider>();
    final wallets = walletProvider.wallets;
    final total = wallets.fold(0.0, (s, w) => s + walletProvider.balanceFor(w.id));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dompet'),
        actions: [
          IconButton(
            tooltip: 'Tambah Dompet',
            icon: const Icon(Icons.add),
            onPressed: () => _addWallet(context, walletProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_wallet_transfer',
        icon: const Icon(Icons.swap_horiz),
        label: const Text('Transfer'),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WalletTransferScreen(
              fromWalletId: kWalletCash,
              toWalletId: kWalletBank,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.8)]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Semua Dompet', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
                const SizedBox(height: 6),
                Text(
                  formatRupiah(total),
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...wallets.map((w) => _WalletCard(wallet: w)),
        ],
      ),
    );
  }

  Future<void> _addWallet(BuildContext context, WalletProvider provider) async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Dompet'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: 'Nama Dompet')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) provider.addWallet(ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  final WalletModel wallet;
  const _WalletCard({required this.wallet});

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final balance = walletProvider.balanceFor(wallet.id);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: GestureDetector(
          onTap: () => _showLogoOptions(context, walletProvider),
          child: _buildAvatar(colorScheme),
        ),
        title: Text(wallet.name),
        trailing: Text(
          formatRupiah(balance),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: balance < 0 ? Colors.red.shade700 : colorScheme.onSurface,
          ),
        ),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _WalletHistoryScreen(wallet: wallet))),
      ),
    );
  }

  Widget _buildAvatar(ColorScheme colorScheme) {
    final path = wallet.imagePath;
    if (path != null && File(path).existsSync()) {
      // BoxFit.contain (not CircleAvatar's own cover-and-crop) so a
      // rectangular/non-square logo always shows in full instead of
      // having its edges cut off to fill the circle.
      return ClipOval(
        child: Container(
          width: 40,
          height: 40,
          color: colorScheme.primaryContainer,
          padding: const EdgeInsets.all(4),
          child: Image.file(File(path), fit: BoxFit.contain),
        ),
      );
    }
    return CircleAvatar(
      backgroundColor: colorScheme.primaryContainer,
      child: Icon(_iconFor(wallet.id), color: colorScheme.onPrimaryContainer),
    );
  }

  void _showLogoOptions(BuildContext context, WalletProvider walletProvider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(wallet.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Pasang gambar logo untuk dompet ini'),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(wallet.imagePath == null ? 'Pasang Logo' : 'Ganti Logo'),
              onTap: () async {
                Navigator.pop(ctx);
                await walletProvider.pickWalletImage(wallet.id);
              },
            ),
            if (wallet.imagePath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Hapus Logo', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await walletProvider.clearWalletImage(wallet.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String id) {
    switch (id) {
      case kWalletCash:
        return Icons.payments_outlined;
      case kWalletSaldoGrab:
        return Icons.local_taxi_outlined;
      case kWalletBank:
        return Icons.account_balance_outlined;
      default:
        return Icons.account_balance_wallet_outlined;
    }
  }
}

class _WalletHistoryScreen extends StatelessWidget {
  final WalletModel wallet;
  const _WalletHistoryScreen({required this.wallet});

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final financeProvider = context.watch<FinanceProvider>();
    final history = walletProvider.historyFor(wallet.id);
    final entries = groupTransactions(history);
    final balance = walletProvider.balanceFor(wallet.id);

    return Scaffold(
      appBar: AppBar(title: Text(wallet.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Center(
            child: Column(
              children: [
                Text('Saldo', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(formatRupiah(balance), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Belum ada riwayat', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            )
          else
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: entries
                    .map((e) => TransactionTile(entry: e, categoryResolver: financeProvider.categoryById))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
