import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/wallet_model.dart';
import '../providers/finance_provider.dart';
import '../providers/wallet_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_period.dart';
import '../widgets/amount_field.dart';

/// Moves money between two dompets. The admin fee field is pre-filled
/// automatically from whatever default was configured in Pengaturan for
/// that exact dompet pair (e.g. Bank -> OVO always costs Rp1.000) — and
/// re-filled whenever either dropdown changes, since the right default
/// depends on exactly which two dompets are involved.
class WalletTransferScreen extends StatefulWidget {
  final String fromWalletId;
  final String toWalletId;
  final String title;

  const WalletTransferScreen({
    super.key,
    required this.fromWalletId,
    required this.toWalletId,
    this.title = 'Transfer Dompet',
  });

  @override
  State<WalletTransferScreen> createState() => _WalletTransferScreenState();
}

class _WalletTransferScreenState extends State<WalletTransferScreen> {
  late String _fromId = widget.fromWalletId;
  late String _toId = widget.toWalletId;
  final _amountCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = nowWib();
  bool _feeInitialized = false;

  double get _amount => parseFormattedAmount(_amountCtrl.text);
  double get _fee => parseFormattedAmount(_feeCtrl.text);

  @override
  void dispose() {
    _amountCtrl.dispose();
    _feeCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final wallets = walletProvider.wallets;
    final colorScheme = Theme.of(context).colorScheme;
    final canSave = _amount > 0 && _fromId != _toId;

    if (!_feeInitialized) {
      _feeInitialized = true;
      _applyDefaultFee(walletProvider);
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Dari Dompet', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _walletDropdown(
            wallets,
            _fromId,
            (v) => setState(() {
              _fromId = v;
              _applyDefaultFee(walletProvider);
            }),
          ),
          const SizedBox(height: 8),
          Center(child: Icon(Icons.arrow_downward, color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          const Text('Ke Dompet', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _walletDropdown(
            wallets,
            _toId,
            (v) => setState(() {
              _toId = v;
              _applyDefaultFee(walletProvider);
            }),
          ),
          const SizedBox(height: 20),
          AmountField(controller: _amountCtrl, label: 'Jumlah', onChanged: (_) => setState(() {})),
          const SizedBox(height: 20),
          AmountField(controller: _feeCtrl, label: 'Biaya Admin (opsional)', onChanged: (_) => setState(() {})),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Kalau diisi, dompet tujuan menerima jumlah di atas dikurangi biaya admin, dan biaya ini tercatat sebagai pengeluaran nyata.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(border: Border.all(color: colorScheme.outlineVariant), borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Text(formatShortDate(_date)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(controller: _noteCtrl, decoration: const InputDecoration(labelText: 'Catatan')),
          if (_amount > 0) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: colorScheme.tertiaryContainer, borderRadius: BorderRadius.circular(14)),
              child: Text(
                'Diterima: ${formatRupiah(_amount - _fee)}',
                style: TextStyle(color: colorScheme.onTertiaryContainer, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: canSave ? _save : null,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Widget _walletDropdown(List<WalletModel> wallets, String value, ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      value: wallets.any((w) => w.id == value) ? value : null,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      ),
      items: wallets.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  /// Re-fills the fee field with whatever default was configured in
  /// Pengaturan for the currently-selected dompet pair (0/none clears
  /// it) — called once for the initial pair and again every time either
  /// dropdown changes.
  void _applyDefaultFee(WalletProvider walletProvider) {
    final fee = walletProvider.adminFeeFor(_fromId, _toId);
    _feeCtrl.text = fee > 0 ? formatPlainThousands(fee) : '';
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

  Future<void> _save() async {
    final finance = context.read<FinanceProvider>();
    await finance.transferBetweenWallets(
      fromWalletId: _fromId,
      toWalletId: _toId,
      amount: _amount,
      date: _date,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      adminFee: _fee,
    );
    if (mounted) Navigator.pop(context);
  }
}
