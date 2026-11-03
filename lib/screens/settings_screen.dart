import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/wallet_provider.dart';
import '../utils/currency_formatter.dart';
import '../widgets/amount_field.dart';
import 'admin_fee_screen.dart';
import 'backup_screen.dart';
import 'categories_screen.dart';
import 'wallet_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _sectionHeader(context, 'Data'),
          _sectionCard([
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('Dompet'),
              subtitle: const Text('Cash, Saldo Grab, Bank — saldo & transfer'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Kategori'),
              subtitle: const Text('Kelola kategori pemasukan & pengeluaran'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen())),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Backup & Pulihkan Data'),
              subtitle: const Text('Simpan atau pulihkan semua catatan'),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen())),
            ),
          ]),
          const SizedBox(height: 24),
          _sectionHeader(context, 'Grab'),
          _sectionCard([
            Consumer<FinanceProvider>(
              builder: (context, financeProvider, _) => ListTile(
                leading: const Icon(Icons.school_outlined),
                title: const Text('Ke Kampus'),
                subtitle: Text('Rp${formatPlainThousands(financeProvider.hargaKeKampus)} / hari — ketuk untuk ubah harga'),
                onTap: () => _editHargaKeKampus(context, financeProvider),
                trailing: Switch(
                  value: financeProvider.aktifKeKampus,
                  onChanged: (v) => financeProvider.setAktifKeKampus(v),
                ),
              ),
            ),
            const Divider(height: 1),
            Consumer<FinanceProvider>(
              builder: (context, financeProvider, _) => ListTile(
                leading: const Icon(Icons.restaurant_outlined),
                title: const Text('Catat Makan'),
                subtitle: Text('Telur Rp${formatPlainThousands(financeProvider.hargaTelur)} / add on — ketuk untuk ubah harga'),
                onTap: () => _editHargaTelur(context, financeProvider),
                trailing: Switch(
                  value: financeProvider.aktifCatatMakan,
                  onChanged: (v) => financeProvider.setAktifCatatMakan(v),
                ),
              ),
            ),
            const Divider(height: 1),
            Consumer<WalletProvider>(
              builder: (context, walletProvider, _) => ListTile(
                leading: const Icon(Icons.account_balance_outlined),
                title: const Text('Biaya Admin Transfer'),
                subtitle: Text(
                  walletProvider.configuredAdminFees.isEmpty
                      ? 'Belum ada default — otomatis terisi kalau sudah diatur'
                      : '${walletProvider.configuredAdminFees.length} pasangan dompet diatur',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminFeeScreen())),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          _sectionHeader(context, 'Tampilan'),
          _sectionCard([
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) => SwitchListTile(
                secondary: Icon(themeProvider.isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
                title: const Text('Mode Gelap'),
                value: themeProvider.isDark,
                onChanged: (_) => themeProvider.toggle(),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _sectionCard(List<Widget> children) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  void _editHargaKeKampus(BuildContext context, FinanceProvider provider) {
    final ctrl = TextEditingController(text: formatPlainThousands(provider.hargaKeKampus));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Harga Ke Kampus'),
        content: AmountField(controller: ctrl, label: 'Harga per hari'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              final value = parseFormattedAmount(ctrl.text);
              if (value > 0) provider.setHargaKeKampus(value);
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _editHargaTelur(BuildContext context, FinanceProvider provider) {
    final ctrl = TextEditingController(text: formatPlainThousands(provider.hargaTelur));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Harga Telur (Add On)'),
        content: AmountField(controller: ctrl, label: 'Harga add on'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              final value = parseFormattedAmount(ctrl.text);
              if (value > 0) provider.setHargaTelur(value);
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
