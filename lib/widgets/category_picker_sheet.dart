import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../providers/finance_provider.dart';
import '../screens/category_edit_screen.dart';
import '../utils/icon_catalog.dart';

Future<CategoryModel?> showCategoryPicker(BuildContext context, TxType type) {
  return showModalBottomSheet<CategoryModel>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => CategoryPickerSheet(type: type),
  );
}

class CategoryPickerSheet extends StatelessWidget {
  final TxType type;

  const CategoryPickerSheet({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final cats = provider.categoriesOfType(type);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pilih Kategori', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: cats.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('Belum ada kategori'),
                    )
                  : GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: cats.length,
                      itemBuilder: (context, i) {
                        final c = cats[i];
                        return InkWell(
                          onTap: () => Navigator.pop(context, c),
                          borderRadius: BorderRadius.circular(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Color(c.colorValue).withOpacity(0.15),
                                child: Icon(iconFromCodePoint(c.iconCodePoint), color: Color(c.colorValue)),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                c.name,
                                style: const TextStyle(fontSize: 12),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final newCat = await Navigator.push<CategoryModel>(
                  context,
                  MaterialPageRoute(builder: (_) => CategoryEditScreen(initialType: type)),
                );
                if (newCat != null && context.mounted) {
                  Navigator.pop(context, newCat);
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Tambah Kategori Baru'),
            ),
          ],
        ),
      ),
    );
  }
}
