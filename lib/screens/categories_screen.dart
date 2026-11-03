import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../providers/finance_provider.dart';
import '../utils/icon_catalog.dart';
import 'category_edit_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategori'),
        bottom: TabBar(controller: _tab, tabs: const [Tab(text: 'Pemasukan'), Tab(text: 'Pengeluaran')]),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_categories',
        onPressed: () {
          final type = _tab.index == 0 ? TxType.income : TxType.expense;
          Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryEditScreen(initialType: type)));
        },
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _CategoryList(categories: provider.categoriesOfType(TxType.income)),
          _CategoryList(categories: provider.categoriesOfType(TxType.expense)),
        ],
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  final List<CategoryModel> categories;

  const _CategoryList({required this.categories});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<FinanceProvider>();
    if (categories.isEmpty) {
      return Center(
        child: Text('Belum ada kategori', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, i) {
        final c = categories[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Color(c.colorValue).withOpacity(0.15),
              child: Icon(iconFromCodePoint(c.iconCodePoint), color: Color(c.colorValue)),
            ),
            title: Text(c.name),
            subtitle: c.isDefault ? const Text('Kategori bawaan') : null,
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'edit') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryEditScreen(existing: c)));
                } else if (v == 'delete') {
                  final ok = await provider.deleteCategory(c.id);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Kategori ini masih dipakai, tidak bisa dihapus')),
                    );
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Hapus')),
              ],
            ),
          ),
        );
      },
    );
  }
}
