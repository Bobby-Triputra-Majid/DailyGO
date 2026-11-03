import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../providers/finance_provider.dart';
import '../utils/icon_catalog.dart';

class CategoryEditScreen extends StatefulWidget {
  final CategoryModel? existing;
  final TxType? initialType;

  const CategoryEditScreen({super.key, this.existing, this.initialType});

  @override
  State<CategoryEditScreen> createState() => _CategoryEditScreenState();
}

class _CategoryEditScreenState extends State<CategoryEditScreen> {
  late TextEditingController _nameCtrl;
  late TxType _type;
  late int _colorValue;
  late int _iconCodePoint;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _type = e?.type ?? widget.initialType ?? TxType.income;
    _colorValue = e?.colorValue ?? categoryColorValues.first;
    _iconCodePoint = e?.iconCodePoint ?? categoryIconChoices.first.codePoint;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Kategori' : 'Tambah Kategori')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Nama Kategori'),
          ),
          const SizedBox(height: 20),
          const Text('Jenis', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<TxType>(
            segments: const [
              ButtonSegment(value: TxType.income, label: Text('Pemasukan')),
              ButtonSegment(value: TxType.expense, label: Text('Pengeluaran')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 20),
          const Text('Ikon', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: categoryIconChoices.map((icon) {
              final selected = icon.codePoint == _iconCodePoint;
              return InkWell(
                onTap: () => setState(() => _iconCodePoint = icon.codePoint),
                borderRadius: BorderRadius.circular(24),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: selected ? Color(_colorValue).withOpacity(0.2) : colorScheme.surfaceContainerHighest,
                  child: Icon(icon, color: selected ? Color(_colorValue) : colorScheme.onSurfaceVariant),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text('Warna', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: categoryColorValues.map((value) {
              final selected = value == _colorValue;
              return InkWell(
                onTap: () => setState(() => _colorValue = value),
                borderRadius: BorderRadius.circular(20),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(value),
                  child: selected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama kategori tidak boleh kosong')));
      return;
    }
    final provider = context.read<FinanceProvider>();
    if (widget.existing != null) {
      final updated = widget.existing!;
      updated.name = name;
      updated.type = _type;
      updated.colorValue = _colorValue;
      updated.iconCodePoint = _iconCodePoint;
      await provider.updateCategory(updated);
      if (mounted) Navigator.pop(context, updated);
    } else {
      final cat = await provider.addCategory(
        name: name,
        type: _type,
        colorValue: _colorValue,
        iconCodePoint: _iconCodePoint,
      );
      if (mounted) Navigator.pop(context, cat);
    }
  }
}
