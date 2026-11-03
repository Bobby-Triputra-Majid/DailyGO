import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../providers/asset_provider.dart';
import '../providers/finance_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_period.dart';
import '../utils/grouping.dart';
import '../widgets/gradient_stat_card.dart';
import '../widgets/period_selector.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';
import 'grab_tab_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'wallet_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  PeriodType _periodType = PeriodType.month;
  DateTime _anchor = nowWib();
  final _searchCtrl = TextEditingController();
  String _query = '';

  /// When on, Saldo also counts piutang that hasn't been paid yet (added)
  /// and utang that hasn't been paid off yet (subtracted) — "what I'd have
  /// if everyone settled up right now" — on top of the real, already-in-hand
  /// balance.
  bool _includePiutang = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final assetProvider = context.watch<AssetProvider>();
    final range = PeriodUtils.rangeFor(_periodType, _anchor);
    // Grab trip money (fare + tip) is real money, so it still counts
    // toward Saldo/Pemasukan here — but the individual "Trip Grab" rows
    // are left out of the recent list, since they're already listed one
    // by one on the Grab tab.
    const tripGrabLabel = 'Trip Grab';
    final income = provider.totalForType(range, TxType.income);
    // Biaya Admin Grab (Grab's own commission) still reduces Saldo for
    // real — allTimeBalance below isn't adjusted — but it's Grab's cut,
    // not something bought, so it's left out of the Pengeluaran figure
    // shown here (still visible in Saldo Grab's own wallet history).
    final adminFeeInRange =
        provider.transactionsInRange(range, categoryId: 'biaya_admin').fold(0.0, (s, t) => s + t.amount);
    final expense = provider.totalForType(range, TxType.expense) - adminFeeInRange;
    // Saldo itself is cumulative (all-time), not limited to the selected
    // period — otherwise it'd look like it resets to 0 every time the
    // period rolls over, even though past income (e.g. savings) is still
    // really there.
    final allTimeBalance = provider.totalAllTime(TxType.income) - provider.totalAllTime(TxType.expense);

    var recentTxs = provider.transactionsInRange(range, excludeGroupLabel: tripGrabLabel);
    if (_query.isNotEmpty) {
      recentTxs = recentTxs.where((t) => t.note != null && t.note!.toLowerCase().contains(_query)).toList();
    }
    final recent = groupTransactions(recentTxs).take(_query.isEmpty ? 6 : 50).toList();

    // Individual Grab trips/fuel/meals still don't show up one by one on
    // Beranda — but their totals for the period do, as a single "Trip
    // Grab" row and a single "Pengeluaran Grab" row, so Grab activity
    // isn't completely invisible here.
    final allInRange = provider.transactionsInRange(range);
    final grabIncomeTxs =
        allInRange.where((t) => t.groupLabel == tripGrabLabel && (t.categoryId == 'grab' || t.categoryId == 'tip')).toList();
    final grabIncomeTotal = grabIncomeTxs.fold(0.0, (s, t) => s + t.amount);
    // Counted by distinct groupId, not row count — a trip billed below
    // the minimum fare books a second 'grab'-category row (the top-up to
    // Saldo Grab), which would otherwise double-count that one trip.
    final tripCount = allInRange
        .where((t) => t.groupLabel == tripGrabLabel && t.categoryId == 'grab')
        .map((t) => t.groupId)
        .toSet()
        .length;
    final grabExpenseTotal = allInRange
        .where((t) => t.categoryId == 'bensin_grab' || (t.categoryId == 'makan' && t.groupLabel == tripGrabLabel))
        .fold(0.0, (s, t) => s + t.amount);

    final summaryTiles = <Widget>[];
    if (_query.isEmpty) {
      if (grabIncomeTotal > 0) {
        summaryTiles.add(_grabSummaryTile(
          icon: Icons.local_taxi,
          color: kStatIncomeColor,
          title: 'Trip Grab',
          subtitle: '$tripCount trip',
          amount: grabIncomeTotal,
          isIncome: true,
        ));
      }
      if (grabExpenseTotal > 0) {
        summaryTiles.add(_grabSummaryTile(
          icon: Icons.local_gas_station,
          color: kStatExpenseColor,
          title: 'Pengeluaran Grab',
          subtitle: 'BBM + Makan',
          amount: grabExpenseTotal,
          isIncome: false,
        ));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Transaksi'),
            Text(
              formatLongDate(nowWib()),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Dompet',
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
          ),
          IconButton(
            tooltip: 'Pengaturan',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_dashboard',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTransactionScreen())),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          PeriodSelector(
              type: _periodType,
              range: range,
              onTypeChanged: (t) => setState(() => _periodType = t),
              onPrev: () => setState(() => _anchor = PeriodUtils.shift(_periodType, _anchor, -1)),
              onNext: () => setState(() => _anchor = PeriodUtils.shift(_periodType, _anchor, 1)),
              onToday: () => setState(() => _anchor = nowWib()),
            ),
            const SizedBox(height: 16),
            GradientStatCard(
              title: _includePiutang ? 'Saldo + Piutang - Utang' : 'Saldo',
              mainValue: _includePiutang
                  ? allTimeBalance + assetProvider.totalReceivable - assetProvider.totalPayable
                  : allTimeBalance,
              toggleOn: _includePiutang,
              onToggle: () => setState(() => _includePiutang = !_includePiutang),
              toggleTooltip: _includePiutang ? 'Sembunyikan piutang/utang dari Saldo' : 'Tambahkan piutang & utang ke Saldo',
              stats: [
                StatItemData(icon: Icons.arrow_downward, label: 'Pemasukan', value: income, color: kStatIncomeColor),
                StatItemData(icon: Icons.arrow_upward, label: 'Pengeluaran', value: expense, color: kStatExpenseColor),
                if (_includePiutang)
                  StatItemData(
                    icon: Icons.call_received,
                    label: 'Piutang',
                    value: assetProvider.totalReceivable,
                    color: kStatIncomeColor,
                  ),
                if (_includePiutang)
                  StatItemData(
                    icon: Icons.call_made,
                    label: 'Utang',
                    value: assetProvider.totalPayable,
                    color: kStatExpenseColor,
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSearchBar(context),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_query.isEmpty ? 'Transaksi Terbaru' : 'Hasil Pencarian', style: Theme.of(context).textTheme.titleMedium),
                if (_query.isEmpty)
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
                    child: const Text('Lihat Semua'),
                  ),
              ],
            ),
            if (recent.isEmpty && summaryTiles.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    _query.isEmpty ? 'Belum ada transaksi di waktu ini' : 'Tidak ada catatan yang cocok',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    ...recent.map((e) => TransactionTile(
                          entry: e,
                          categoryResolver: provider.categoryById,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AddTransactionScreen(existing: e.primary)),
                          ),
                          onDelete: () => _confirmDelete(context, provider, e),
                        )),
                    if (summaryTiles.isNotEmpty) ...[
                      if (recent.isNotEmpty) const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          'Aktivitas Grab',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      ...summaryTiles,
                    ],
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, FinanceProvider provider, DisplayEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi'),
        content: const Text('Hapus transaksi ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              provider.deleteTransaction(entry.primary.id);
              Navigator.pop(ctx, true);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// One aggregated row standing in for every individual Grab trip/fuel/
  /// meal entry for the period — tapping it goes to the Grab tab, since
  /// there's no single transaction here to edit.
  Widget _grabSummaryTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required double amount,
    required bool isIncome,
  }) {
    return ListTile(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GrabTabScreen())),
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.15),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        '${isIncome ? '+' : '-'}${formatRupiah(amount)}',
        style: TextStyle(
          color: isIncome ? Colors.green.shade700 : Colors.red.shade700,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return TextField(
      controller: _searchCtrl,
      onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
      decoration: InputDecoration(
        hintText: 'Cari',
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
    );
  }

}
