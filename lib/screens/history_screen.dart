import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../providers/finance_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_period.dart';
import '../utils/grouping.dart';
import '../utils/icon_catalog.dart';
import '../widgets/period_selector.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  PeriodType _periodType = PeriodType.month;
  DateTime _anchor = nowWib();
  TxType? _typeFilter;
  String? _categoryFilter;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final range = PeriodUtils.rangeFor(_periodType, _anchor);
    var txs = provider.transactionsInRange(range, type: _typeFilter, categoryId: _categoryFilter);
    if (_query.isNotEmpty) {
      txs = txs.where((t) => t.note != null && t.note!.toLowerCase().contains(_query)).toList();
    }
    final entries = groupTransactions(txs);

    final grouped = <String, List<DisplayEntry>>{};
    for (final e in entries) {
      grouped.putIfAbsent(_dateKey(e.date), () => []).add(e);
    }

    final categoryOptions = _typeFilter != null ? provider.categoriesOfType(_typeFilter!) : provider.categories;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Transaksi')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          children: [
            PeriodSelector(
              type: _periodType,
              range: range,
              onTypeChanged: (t) => setState(() => _periodType = t),
              onPrev: () => setState(() => _anchor = PeriodUtils.shift(_periodType, _anchor, -1)),
              onNext: () => setState(() => _anchor = PeriodUtils.shift(_periodType, _anchor, 1)),
              onToday: () => setState(() => _anchor = nowWib()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Cari dari catatan...',
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
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _FilterDropdown<TxType?>(
                    value: _typeFilter,
                    items: const {null: 'Semua Jenis', TxType.income: 'Pemasukan', TxType.expense: 'Pengeluaran'},
                    onChanged: (v) => setState(() {
                      _typeFilter = v;
                      _categoryFilter = null;
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FilterDropdown<String?>(
                    value: _categoryFilter,
                    items: {
                      null: 'Semua Kategori',
                      for (final c in categoryOptions) c.id: c.name,
                    },
                    onChanged: (v) => setState(() => _categoryFilter = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        _query.isNotEmpty ? 'Tidak ada catatan yang cocok' : 'Belum ada transaksi',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    )
                  : Builder(builder: (context) {
                      final groupList = grouped.entries.toList();
                      return ListView.builder(
                        itemCount: groupList.length,
                        itemBuilder: (context, index) {
                          final g = groupList[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  g.key,
                                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                              ),
                              Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Column(
                                  children: g.value
                                      .map((e) => TransactionTile(
                                            entry: e,
                                            categoryResolver: provider.categoryById,
                                            onTap: () => _openEntry(context, e),
                                            onDelete: () => _confirmDelete(context, provider, e),
                                          ))
                                      .toList(),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    }),
            ),
          ],
        ),
      ),
    );
  }

  String _dateKey(DateTime d) {
    final now = nowWib();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return 'Hari ini';
    if (day == today.subtract(const Duration(days: 1))) return 'Kemarin';
    return formatShortDate(d);
  }

  void _openEntry(BuildContext context, DisplayEntry entry) {
    if (entry.isGroup) {
      _showGroupDetail(context, entry);
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => AddTransactionScreen(existing: entry.primary)));
  }

  void _showGroupDetail(BuildContext context, DisplayEntry entry) {
    final provider = context.read<FinanceProvider>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.groupLabel ?? 'Detail', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                ...entry.transactions.map((t) {
                  final c = provider.categoryById(t.categoryId);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: c != null ? Color(c.colorValue).withOpacity(0.15) : null,
                      child: Icon(c != null ? iconFromCodePoint(c.iconCodePoint) : Icons.circle),
                    ),
                    title: Text(c?.name ?? '-'),
                    trailing: Text(formatRupiah(t.amount)),
                  );
                }),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Text(formatRupiah(entry.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmDelete(BuildContext context, FinanceProvider provider, DisplayEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi'),
        content: Text(entry.isGroup ? 'Hapus semua catatan trip ini?' : 'Hapus transaksi ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              if (entry.isGroup) {
                provider.deleteGroup(entry.groupId!);
              } else {
                provider.deleteTransaction(entry.primary.id);
              }
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

class _FilterDropdown<T> extends StatelessWidget {
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  const _FilterDropdown({required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: items.entries
              .map((e) => DropdownMenuItem<T>(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) => onChanged(v as T),
        ),
      ),
    );
  }
}
