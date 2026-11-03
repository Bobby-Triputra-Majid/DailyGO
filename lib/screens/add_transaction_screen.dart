import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../providers/finance_provider.dart';
import '../providers/wallet_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_period.dart';
import '../utils/icon_catalog.dart';
import '../widgets/amount_field.dart';
import '../widgets/category_picker_sheet.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionModel? existing;

  /// Pre-select a type and category on a brand-new entry (ignored when
  /// [existing] is set) — e.g. opening straight into "Pengeluaran / BBM
  /// Grab" from the Grab tab instead of making the user pick it.
  final TxType? initialType;
  final String? initialCategoryId;

  const AddTransactionScreen({super.key, this.existing, this.initialType, this.initialCategoryId});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  late TxType _type;
  late TextEditingController _amountCtrl;
  late TextEditingController _noteCtrl;
  late DateTime _date;
  CategoryModel? _category;
  bool _categoryLoaded = false;
  late String _walletId;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? widget.initialType ?? TxType.income;
    _amountCtrl = TextEditingController(text: e != null ? formatPlainThousands(e.amount) : '');
    _noteCtrl = TextEditingController(text: e?.note ?? '');
    _date = e?.date ?? nowWib();
    _walletId = e?.walletId ?? kWalletCash;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<FinanceProvider>();
    if (!_categoryLoaded) {
      final presetId = widget.existing?.categoryId ?? widget.initialCategoryId;
      if (presetId != null) _category = provider.categoryById(presetId);
      _categoryLoaded = true;
    }
    final isEdit = widget.existing != null;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Transaksi' : 'Transaksi Baru'),
        actions: isEdit
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, provider),
                ),
              ]
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<TxType>(
            segments: const [
              ButtonSegment(value: TxType.income, label: Text('Pemasukan'), icon: Icon(Icons.arrow_downward)),
              ButtonSegment(value: TxType.expense, label: Text('Pengeluaran'), icon: Icon(Icons.arrow_upward)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              _category = null;
            }),
          ),
          const SizedBox(height: 20),
          AmountField(controller: _amountCtrl, label: 'Jumlah'),
          const SizedBox(height: 20),
          const Text('Kategori', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final cat = await showCategoryPicker(context, _type);
              if (cat != null) setState(() => _category = cat);
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(border: Border.all(color: colorScheme.outlineVariant), borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  if (_category != null) ...[
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(_category!.colorValue).withOpacity(0.15),
                      child: Icon(iconFromCodePoint(_category!.iconCodePoint), size: 16, color: Color(_category!.colorValue)),
                    ),
                    const SizedBox(width: 10),
                    Text(_category!.name),
                  ] else
                    Text('Pilih kategori', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Dompet', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Consumer<WalletProvider>(
            builder: (context, walletProvider, _) {
              final wallets = walletProvider.wallets;
              if (!wallets.any((w) => w.id == _walletId) && wallets.isNotEmpty) {
                _walletId = wallets.first.id;
              }
              return DropdownButtonFormField<String>(
                value: _walletId,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                ),
                items: wallets.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                onChanged: (v) => setState(() => _walletId = v ?? _walletId),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text('Tanggal', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(border: Border.all(color: colorScheme.outlineVariant), borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Text(formatShortDate(_date)),
                  const Spacer(),
                  Icon(Icons.calendar_today, size: 18, color: colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Catatan'),
            maxLines: 2,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => _save(context, provider),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: Text(isEdit ? 'Simpan Perubahan' : 'Simpan Transaksi'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: nowWib().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _date = DateTime(picked.year, picked.month, picked.day, _date.hour, _date.minute));
    }
  }

  Future<void> _save(BuildContext context, FinanceProvider provider) async {
    final amount = parseFormattedAmount(_amountCtrl.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Isi jumlah uangnya dulu')));
      return;
    }
    if (_category == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih kategori dulu')));
      return;
    }

    if (widget.existing != null) {
      final tx = widget.existing!;
      tx.type = _type;
      tx.amount = amount;
      tx.categoryId = _category!.id;
      tx.date = _date;
      tx.note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
      tx.walletId = _walletId;
      await provider.updateTransaction(tx);
    } else {
      final tx = TransactionModel(
        id: provider.generateId(),
        type: _type,
        amount: amount,
        categoryId: _category!.id,
        date: _date,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        walletId: _walletId,
      );
      await provider.addTransaction(tx);
    }
    if (context.mounted) Navigator.pop(context);
  }

  void _confirmDelete(BuildContext context, FinanceProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Transaksi'),
        content: const Text('Catatan ini akan dihapus selamanya.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () async {
              await provider.deleteTransaction(widget.existing!.id);
              if (context.mounted) {
                Navigator.pop(ctx);
                Navigator.pop(context);
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
