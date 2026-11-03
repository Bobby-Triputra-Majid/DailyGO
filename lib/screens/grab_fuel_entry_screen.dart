import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_period.dart';
import '../widgets/amount_field.dart';

/// Quick-entry screen for a BBM Grab fill-up.
///
/// Fuel isn't always topped up every day, so when a fill-up also covers
/// riding "ke kampus" (to campus) on days in between, checking "Ke
/// Kampus" splits off `hariKeKampus * hargaKeKampus` as a personal "BBM"
/// expense (shown on Beranda like any everyday expense) and books the
/// rest as "BBM Grab". The price per trip is set in Pengaturan.
class GrabFuelEntryScreen extends StatefulWidget {
  const GrabFuelEntryScreen({super.key});

  @override
  State<GrabFuelEntryScreen> createState() => _GrabFuelEntryScreenState();
}

class _GrabFuelEntryScreenState extends State<GrabFuelEntryScreen> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = nowWib();
  bool _keKampus = false;
  int _hariKeKampus = 1;

  double get _total => parseFormattedAmount(_amountCtrl.text);

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<FinanceProvider>();
    final hargaKeKampus = provider.hargaKeKampus;
    final colorScheme = Theme.of(context).colorScheme;

    final kampusAmount = _keKampus ? _hariKeKampus * hargaKeKampus : 0.0;
    final grabAmount = _total - kampusAmount;
    final exceeds = _keKampus && _total > 0 && kampusAmount > _total;

    return Scaffold(
      appBar: AppBar(title: const Text('Isi BBM Grab')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AmountField(
            controller: _amountCtrl,
            label: 'Jumlah Isi BBM',
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
          if (provider.aktifKeKampus) ...[
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(border: Border.all(color: colorScheme.outlineVariant), borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  CheckboxListTile(
                    value: _keKampus,
                    onChanged: (v) => setState(() => _keKampus = v ?? false),
                    title: const Text('Ke Kampus'),
                    subtitle: Text('Rp${formatPlainThousands(hargaKeKampus)} / hari, bisa diubah di Pengaturan'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (_keKampus)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Row(
                        children: [
                          const Text('Berapa hari ke kampus?'),
                          const Spacer(),
                          IconButton(
                            onPressed: _hariKeKampus > 1 ? () => setState(() => _hariKeKampus--) : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text('$_hariKeKampus', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          IconButton(
                            onPressed: () => setState(() => _hariKeKampus++),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
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
          if (exceeds)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: colorScheme.errorContainer, borderRadius: BorderRadius.circular(10)),
              child: Text(
                'Jatah ke kampus lebih besar dari jumlah isi BBM.',
                style: TextStyle(color: colorScheme.onErrorContainer, fontWeight: FontWeight.w600),
              ),
            )
          else if (_total > 0 && _keKampus)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: colorScheme.tertiaryContainer, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _breakdownRow('Ke Kampus (BBM)', kampusAmount, colorScheme.onTertiaryContainer),
                  _breakdownRow('BBM Grab', grabAmount, colorScheme.onTertiaryContainer),
                ],
              ),
            ),
          const SizedBox(height: 24),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Catatan'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: (exceeds || _total <= 0) ? null : () => _save(context, provider),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: color)),
          Text(formatRupiah(value), style: TextStyle(color: color, fontWeight: FontWeight.w600)),
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
    await provider.addGrabFuel(
      totalAmount: _total,
      date: _date,
      kampusCount: _keKampus ? _hariKeKampus : 0,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );
    if (context.mounted) Navigator.pop(context);
  }
}
