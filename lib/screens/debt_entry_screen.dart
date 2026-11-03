import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/debt_model.dart';
import '../providers/asset_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_period.dart';
import '../widgets/amount_field.dart';

class DebtEntryScreen extends StatefulWidget {
  final String? initialName;
  final DebtModel? existing;

  /// Which side is pre-selected for a brand-new record (ignored when
  /// [existing] is set) — e.g. the Utang tab's FAB passes [iOweThem] so
  /// adding from there doesn't default to Piutang first.
  final DebtDirection initialDirection;

  const DebtEntryScreen({super.key, this.initialName, this.existing, this.initialDirection = DebtDirection.theyOweMe});

  @override
  State<DebtEntryScreen> createState() => _DebtEntryScreenState();
}

class _DebtEntryScreenState extends State<DebtEntryScreen> {
  late final _nameCtrl = TextEditingController(text: widget.existing?.personName ?? widget.initialName ?? '');
  late final _amountCtrl = TextEditingController(
    text: widget.existing != null ? formatPlainThousands(widget.existing!.amount) : '',
  );
  late final _noteCtrl = TextEditingController(text: widget.existing?.note ?? '');
  late DebtDirection _direction = widget.existing?.direction ?? widget.initialDirection;
  late DateTime _date = widget.existing?.date ?? nowWib();

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final amount = parseFormattedAmount(_amountCtrl.text);
    final canSave = _nameCtrl.text.trim().isNotEmpty && amount > 0;
    final knownNames =
        (!_isEdit && widget.initialName == null) ? context.watch<AssetProvider>().knownPersonNames : const <String>[];

    final title = _isEdit ? 'Edit Utang/Piutang' : (_direction == DebtDirection.theyOweMe ? 'Tambah Piutang' : 'Tambah Utang');

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: _isEdit
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _confirmDelete,
                ),
              ]
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<DebtDirection>(
            segments: const [
              ButtonSegment(value: DebtDirection.theyOweMe, label: Text('Piutang')),
              ButtonSegment(value: DebtDirection.iOweThem, label: Text('Utang')),
            ],
            selected: {_direction},
            onSelectionChanged: (s) => setState(() => _direction = s.first),
          ),
          const SizedBox(height: 6),
          Text(
            _direction == DebtDirection.theyOweMe ? 'Piutang: orang lain berutang ke Anda' : 'Utang: Anda berutang ke orang lain',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12.5),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Nama Orang'),
            onChanged: (_) => setState(() {}),
          ),
          if (knownNames.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Atau pilih yang sudah ada:', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12.5)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: knownNames
                  .map((name) => ActionChip(
                        label: Text(name),
                        onPressed: () => setState(() => _nameCtrl.text = name),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 20),
          AmountField(controller: _amountCtrl, label: 'Jumlah', onChanged: (_) => setState(() {})),
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
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Catatan'),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: canSave ? _save : null,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: const Text('Simpan'),
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

  Future<void> _save() async {
    final provider = context.read<AssetProvider>();
    if (_isEdit) {
      final debt = widget.existing!;
      debt.personName = _nameCtrl.text.trim();
      debt.amount = parseFormattedAmount(_amountCtrl.text);
      debt.direction = _direction;
      debt.date = _date;
      debt.note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
      await provider.updateDebt(debt);
    } else {
      await provider.addDebt(
        personName: _nameCtrl.text.trim(),
        amount: parseFormattedAmount(_amountCtrl.text),
        direction: _direction,
        date: _date,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Catatan'),
        content: const Text('Catatan utang/piutang ini akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              context.read<AssetProvider>().deleteDebt(widget.existing!.id);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
