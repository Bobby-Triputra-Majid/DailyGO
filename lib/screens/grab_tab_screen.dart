import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../providers/finance_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_period.dart';
import '../utils/grouping.dart';
import '../widgets/amount_field.dart';
import '../widgets/gradient_stat_card.dart';
import '../widgets/period_selector.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';
import 'grab_entry_screen.dart';
import 'grab_fuel_entry_screen.dart';

/// Dedicated tab for Grab trips: quick access to add a trip or a
/// Grab-related fuel expense, see how much was earned/spent in the
/// selected period, and browse past entries. Everything recorded here is
/// an ordinary income/expense transaction, so it's already included in
/// the Beranda (dashboard) totals automatically — "BBM Grab" is kept as
/// its own category, separate from the everyday "BBM" category, so fuel
/// bought for Grab work doesn't get mixed into daily fuel spending.
class GrabTabScreen extends StatefulWidget {
  const GrabTabScreen({super.key});

  @override
  State<GrabTabScreen> createState() => _GrabTabScreenState();
}

class _GrabTabScreenState extends State<GrabTabScreen> {
  PeriodType _periodType = PeriodType.day;
  DateTime _anchor = nowWib();

  /// BBM is usually bought in one lump sum that lasts several days, so
  /// subtracting it (and Makan) in full from whichever single day it was
  /// bought/eaten makes that day's Pendapatan Bersih look misleadingly low
  /// (and every other day look misleadingly high). Off by default so the
  /// figure reflects the day's trip earnings on their own; turn on to see
  /// the real net after BBM + Makan.
  bool _includeCostsInNet = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final range = PeriodUtils.rangeFor(_periodType, _anchor);
    final txsInRange = provider.transactionsInRange(range);
    // 'biaya_admin' (Grab's commission on a cash trip with a system cut)
    // is included here too, purely so grouping nets it against the
    // fare/tip it belongs to — each trip's card then shows what was
    // actually earned net of that commission, not just the gross cash
    // collected. fareTotal/tipTotal below still filter to their own
    // exact category, so the stat card above isn't affected by this.
    final grabTxs = txsInRange
        .where((t) =>
            t.groupLabel == 'Trip Grab' && (t.categoryId == 'grab' || t.categoryId == 'tip' || t.categoryId == 'biaya_admin'))
        .toList();
    final fuelTxs = txsInRange.where((t) => t.categoryId == 'bensin_grab').toList();
    // "Makan" recorded from a Trip Grab entry is a Grab work cost, so it's
    // tagged the same way and lives here — not on Beranda's quick list —
    // and comes out of Pendapatan Bersih below.
    final makanTxs = txsInRange.where((t) => t.categoryId == 'makan' && t.groupLabel == 'Trip Grab').toList();
    final tripEntries = groupTransactions(grabTxs);
    final fuelEntries = groupTransactions(fuelTxs);
    final makanEntries = groupTransactions(makanTxs);

    final fareTotal = grabTxs.where((t) => t.categoryId == 'grab').fold(0.0, (s, t) => s + t.amount);
    final tipTotal = grabTxs.where((t) => t.categoryId == 'tip').fold(0.0, (s, t) => s + t.amount);
    final adminFeeTotal = grabTxs.where((t) => t.categoryId == 'biaya_admin').fold(0.0, (s, t) => s + t.amount);
    final fuelTotal = fuelTxs.fold(0.0, (s, t) => s + t.amount);
    final makanTotal = makanTxs.fold(0.0, (s, t) => s + t.amount);
    // Grab's commission always comes out — unlike BBM/Makan, it's a direct
    // cost of the trip itself, not a lump sum that would distort a single
    // day — so it's subtracted regardless of the eye toggle, and also shown
    // as its own stat chip below so the gap from Ongkos+Tip isn't a mystery.
    final netTotal = fareTotal + tipTotal - adminFeeTotal - (_includeCostsInNet ? (fuelTotal + makanTotal) : 0);
    final colorScheme = Theme.of(context).colorScheme;

    // Net total for the equivalent previous period (e.g. yesterday, for
    // the "stonk" up/down trend badge on the card).
    final previousRange = PeriodUtils.rangeFor(_periodType, PeriodUtils.shift(_periodType, _anchor, -1));
    final previousTxs = provider.transactionsInRange(previousRange);
    final previousGrabTxs = previousTxs
        .where((t) => t.groupLabel == 'Trip Grab' && (t.categoryId == 'grab' || t.categoryId == 'tip'))
        .toList();
    final previousFuelTotal = previousTxs.where((t) => t.categoryId == 'bensin_grab').fold(0.0, (s, t) => s + t.amount);
    final previousMakanTotal = previousTxs
        .where((t) => t.categoryId == 'makan' && t.groupLabel == 'Trip Grab')
        .fold(0.0, (s, t) => s + t.amount);
    final previousAdminFeeTotal = previousTxs
        .where((t) => t.categoryId == 'biaya_admin' && t.groupLabel == 'Trip Grab')
        .fold(0.0, (s, t) => s + t.amount);
    final previousFareTotal = previousGrabTxs.where((t) => t.categoryId == 'grab').fold(0.0, (s, t) => s + t.amount);
    final previousTipTotal = previousGrabTxs.where((t) => t.categoryId == 'tip').fold(0.0, (s, t) => s + t.amount);
    final previousNetTotal = previousFareTotal +
        previousTipTotal -
        previousAdminFeeTotal -
        (_includeCostsInNet ? (previousFuelTotal + previousMakanTotal) : 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grab'),
        actions: [
          if (provider.aktifCatatMakan)
            IconButton(
              tooltip: 'Catat Makan',
              icon: const Icon(Icons.restaurant_outlined),
              onPressed: () => _showMakanSheet(context, provider),
            ),
          IconButton(
            tooltip: 'Isi BBM',
            icon: const Icon(Icons.local_gas_station_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GrabFuelEntryScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_grab_add',
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GrabEntryScreen())),
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
            title: 'Pendapatan Bersih',
            mainValue: netTotal,
            previousValue: previousNetTotal,
            subtitle: _includeCostsInNet
                ? '${tripEntries.length} trip · termasuk BBM & Makan'
                : '${tripEntries.length} trip · belum termasuk BBM & Makan',
            toggleOn: _includeCostsInNet,
            onToggle: () => setState(() => _includeCostsInNet = !_includeCostsInNet),
            toggleTooltip: _includeCostsInNet
                ? 'Sembunyikan BBM & Makan dari Pendapatan Bersih'
                : 'Lihat Pendapatan Bersih setelah dikurangi BBM & Makan',
            stats: [
              // Shown net of Biaya Admin (Grab's commission) so this chip
              // plus Tip always adds up to Pendapatan Bersih above, instead
              // of the gross fare leaving an unexplained gap.
              StatItemData(
                icon: Icons.local_taxi,
                label: 'Ongkos',
                value: fareTotal - adminFeeTotal,
                color: kStatIncomeColor,
              ),
              StatItemData(icon: Icons.card_giftcard, label: 'Tip', value: tipTotal, color: kStatIncomeColor),
              StatItemData(
                icon: Icons.arrow_upward,
                label: 'Pengeluaran',
                value: _includeCostsInNet ? (fuelTotal + makanTotal) : 0,
                color: kStatExpenseColor,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Daftar Trip', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (tripEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Belum ada trip Grab di waktu ini', style: TextStyle(color: colorScheme.onSurfaceVariant)),
              ),
            )
          else
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: tripEntries.map((e) {
                  final note = _tripTrailingNote(e);
                  return TransactionTile(
                    entry: e,
                    categoryResolver: provider.categoryById,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => GrabEntryScreen(existing: e)),
                    ),
                    onDelete: () => _confirmDeleteTrip(context, provider, e),
                    titleBadge: _paymentBadge(e),
                    trailingNote: note?.$1,
                    trailingNoteIcon: note?.$2,
                    trailingNoteColor: note?.$3,
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 20),
          Text('BBM Grab', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (fuelEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Belum ada isi minyak Grab di waktu ini', style: TextStyle(color: colorScheme.onSurfaceVariant)),
              ),
            )
          else
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: fuelEntries
                    .map((e) => TransactionTile(
                          entry: e,
                          categoryResolver: provider.categoryById,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AddTransactionScreen(existing: e.primary)),
                          ),
                          onDelete: () => _confirmDeleteFuel(context, provider, e),
                        ))
                    .toList(),
              ),
            ),
          const SizedBox(height: 20),
          Text('Makan', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (makanEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Belum ada catatan makan di waktu ini', style: TextStyle(color: colorScheme.onSurfaceVariant)),
              ),
            )
          else
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: makanEntries
                    .map((e) => TransactionTile(
                          entry: e,
                          categoryResolver: provider.categoryById,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AddTransactionScreen(existing: e.primary)),
                          ),
                          onDelete: () => _confirmDeleteMakan(context, provider, e),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  /// Tunai/Non-Tunai pill shown right next to the trip's title — green for
  /// cash, blue for non-cash — so it doesn't add extra height to the card.
  /// Trips recorded before this field existed have no [isCash] data, so
  /// they just show no pill.
  Widget? _paymentBadge(DisplayEntry e) {
    final isCash = e.primary.isCash;
    if (isCash == null) return null;
    final isOffline = e.primary.isOffline ?? false;
    final color = isCash ? Colors.green : Colors.blue;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
            child: Text(
              isCash ? 'Tunai' : 'Non-Tunai',
              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (isOffline)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: Colors.orange.shade700, borderRadius: BorderRadius.circular(8)),
              child: const Text(
                'Offline',
                style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }

  /// Small icon under a trip's amount — a tip, or a cash shortage (the
  /// passenger paid less than billed). At most one applies at a time:
  /// [FinanceProvider.resolveFareAndTip] never books both on the same
  /// trip. Trips recorded before these fields existed show neither.
  (String, IconData, Color)? _tripTrailingNote(DisplayEntry e) {
    final fare = e.primary;
    final tipAmount = e.transactions.where((t) => t.categoryId == 'tip').fold(0.0, (s, t) => s + t.amount);
    if (tipAmount > 0) return (formatRupiah(tipAmount), Icons.card_giftcard, Colors.blue);

    final billed = fare.billedAmount;
    final received = fare.receivedAmount;
    if (billed != null && received != null && received < billed) {
      return (formatRupiah(billed - received), Icons.money_off, Colors.red);
    }
    return null;
  }

  void _showMakanSheet(BuildContext context, FinanceProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _MakanQuickSheet(provider: provider),
    );
  }

  Future<bool> _confirmDeleteTrip(BuildContext context, FinanceProvider provider, DisplayEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Trip'),
        content: const Text('Hapus trip Grab ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              provider.deleteGroup(entry.groupId!);
              Navigator.pop(ctx, true);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<bool> _confirmDeleteMakan(BuildContext context, FinanceProvider provider, DisplayEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Catatan'),
        content: const Text('Catatan biaya makan ini akan dihapus.'),
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

  Future<bool> _confirmDeleteFuel(BuildContext context, FinanceProvider provider, DisplayEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Catatan'),
        content: const Text('Catatan isi minyak ini akan dihapus.'),
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
}

/// Quick "Catat Makan" sheet opened from the Grab tab's app bar — unlike
/// the once-a-day checkbox inside a trip entry, this can be used as many
/// times a day as needed (e.g. logging a separate meal later in the
/// shift), and books straight to the "makan" category under "Trip Grab"
/// like any other Grab-related cost.
class _MakanQuickSheet extends StatefulWidget {
  final FinanceProvider provider;

  const _MakanQuickSheet({required this.provider});

  @override
  State<_MakanQuickSheet> createState() => _MakanQuickSheetState();
}

class _MakanQuickSheetState extends State<_MakanQuickSheet> {
  final _amountCtrl = TextEditingController();
  bool _telur = false;
  int _telurCount = 1;

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hargaTelur = widget.provider.hargaTelur;
    final makanAmount = parseFormattedAmount(_amountCtrl.text);
    final total = makanAmount + (_telur ? _telurCount * hargaTelur : 0);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Catat Makan', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          AmountField(
            controller: _amountCtrl,
            label: 'Biaya Makan',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 4),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _telur,
            onChanged: (v) => setState(() => _telur = v ?? false),
            title: Text('+ Telur (Rp${formatPlainThousands(hargaTelur)} / butir)'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (_telur)
            Row(
              children: [
                const Text('Jumlah telur'),
                const Spacer(),
                IconButton(
                  onPressed: _telurCount > 1 ? () => setState(() => _telurCount--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_telurCount', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                IconButton(
                  onPressed: () => setState(() => _telurCount++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          const SizedBox(height: 8),
          if (total > 0)
            Align(
              alignment: Alignment.centerRight,
              child: Text('Total: ${formatRupiah(total)}', style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: total <= 0 ? null : () => _save(total),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _save(double total) async {
    final telurNote = _telurCount == 1 ? 'Telur' : '$_telurCount Telur';
    await widget.provider.addTransaction(TransactionModel(
      id: widget.provider.generateId(),
      type: TxType.expense,
      amount: total,
      categoryId: 'makan',
      date: nowWib(),
      note: _telur ? 'Makan + $telurNote' : 'Makan',
      groupLabel: 'Trip Grab',
      walletId: kWalletCash,
    ));
    if (mounted) Navigator.pop(context);
  }
}
