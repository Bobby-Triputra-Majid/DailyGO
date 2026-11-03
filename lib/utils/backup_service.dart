import 'dart:convert';
import '../data/hive_boxes.dart';
import '../models/category_model.dart';
import '../models/debt_model.dart';
import '../models/transaction_model.dart';
import 'date_period.dart';

/// Serializes/restores everything in Hive (categories, transactions,
/// debts) as plain JSON, so the user has a way to back their data up and
/// bring it back later — local storage alone can be wiped by an app
/// uninstall or a cleared browser cache.
class BackupService {
  static const int _version = 1;

  static String exportToJson() {
    final data = {
      'version': _version,
      'exportedAt': nowWib().toIso8601String(),
      'categories': HiveBoxes.categories.values.map(_categoryToMap).toList(),
      'transactions': HiveBoxes.transactions.values.map(_transactionToMap).toList(),
      'debts': HiveBoxes.debts.values.map(_debtToMap).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Replaces everything currently stored with the contents of [jsonStr].
  static Future<void> importFromJson(String jsonStr) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    final categories = (data['categories'] as List? ?? [])
        .map((m) => _categoryFromMap(m as Map<String, dynamic>))
        .toList();
    final transactions = (data['transactions'] as List? ?? [])
        .map((m) => _transactionFromMap(m as Map<String, dynamic>))
        .toList();
    final debts = (data['debts'] as List? ?? [])
        .map((m) => _debtFromMap(m as Map<String, dynamic>))
        .toList();

    await HiveBoxes.categories.clear();
    await HiveBoxes.transactions.clear();
    await HiveBoxes.debts.clear();

    for (final c in categories) {
      await HiveBoxes.categories.put(c.id, c);
    }
    for (final t in transactions) {
      await HiveBoxes.transactions.put(t.id, t);
    }
    for (final d in debts) {
      await HiveBoxes.debts.put(d.id, d);
    }
  }

  static Map<String, dynamic> _categoryToMap(CategoryModel c) => {
        'id': c.id,
        'name': c.name,
        'type': c.type.index,
        'colorValue': c.colorValue,
        'iconCodePoint': c.iconCodePoint,
        'isDefault': c.isDefault,
      };

  static CategoryModel _categoryFromMap(Map<String, dynamic> m) => CategoryModel(
        id: m['id'] as String,
        name: m['name'] as String,
        type: TxType.values[m['type'] as int],
        colorValue: m['colorValue'] as int,
        iconCodePoint: m['iconCodePoint'] as int,
        isDefault: m['isDefault'] as bool? ?? false,
      );

  static Map<String, dynamic> _transactionToMap(TransactionModel t) => {
        'id': t.id,
        'type': t.type.index,
        'amount': t.amount,
        'categoryId': t.categoryId,
        'date': t.date.toIso8601String(),
        'note': t.note,
        'groupId': t.groupId,
        'groupLabel': t.groupLabel,
      };

  static TransactionModel _transactionFromMap(Map<String, dynamic> m) => TransactionModel(
        id: m['id'] as String,
        type: TxType.values[m['type'] as int],
        amount: (m['amount'] as num).toDouble(),
        categoryId: m['categoryId'] as String,
        date: DateTime.parse(m['date'] as String),
        note: m['note'] as String?,
        groupId: m['groupId'] as String?,
        groupLabel: m['groupLabel'] as String?,
      );

  static Map<String, dynamic> _debtToMap(DebtModel d) => {
        'id': d.id,
        'personName': d.personName,
        'amount': d.amount,
        'direction': d.direction.index,
        'date': d.date.toIso8601String(),
        'note': d.note,
        'isPaid': d.isPaid,
        'paidDate': d.paidDate?.toIso8601String(),
        'paidAmount': d.paidAmount,
        'settlementTransactionIds': d.settlementTransactionIds,
      };

  static DebtModel _debtFromMap(Map<String, dynamic> m) => DebtModel(
        id: m['id'] as String,
        personName: m['personName'] as String,
        amount: (m['amount'] as num).toDouble(),
        direction: DebtDirection.values[m['direction'] as int],
        date: DateTime.parse(m['date'] as String),
        note: m['note'] as String?,
        isPaid: m['isPaid'] as bool? ?? false,
        paidDate: m['paidDate'] == null ? null : DateTime.parse(m['paidDate'] as String),
        paidAmount: (m['paidAmount'] as num?)?.toDouble() ?? 0.0,
        settlementTransactionIds:
            (m['settlementTransactionIds'] as List?)?.map((e) => e as String).toList() ?? const [],
      );
}
