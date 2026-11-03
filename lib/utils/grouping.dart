import '../models/category_model.dart';
import '../models/transaction_model.dart';

/// A single row to display in a transaction list. Transactions that share
/// a `groupId` (e.g. a Grab fare + its auto-detected tip) are collapsed
/// into one entry so they read as a single trip in the UI.
class DisplayEntry {
  final List<TransactionModel> transactions;

  DisplayEntry(this.transactions);

  bool get isGroup => transactions.length > 1;

  /// The transaction whose icon/category/note represents the whole group
  /// — the Grab fare when there is one, since a trip's tip/admin-fee/
  /// minimum-fare-top-up legs share the same date and would otherwise end
  /// up first (and so become the shown icon/note) depending on sort
  /// order, which made the row's icon and text flicker between runs. The
  /// fare itself is identified by [TransactionModel.billedAmount] being
  /// set, not just by category — a cash trip billed below the minimum
  /// fare also books its top-up under the 'grab' category (in a
  /// different dompet), so category alone can't tell the two apart.
  /// Falls back to the first transaction for every other kind of group
  /// (e.g. a wallet transfer).
  TransactionModel get primary {
    for (final t in transactions) {
      if (t.categoryId == 'grab' && t.billedAmount != null) return t;
    }
    for (final t in transactions) {
      if (t.categoryId == 'grab') return t;
    }
    return transactions.first;
  }

  DateTime get date => primary.date;
  String? get groupLabel => primary.groupLabel;
  String? get groupId => primary.groupId;

  /// Net of every transaction in the group — income added, expense
  /// subtracted — so a group that mixes the two (e.g. a Grab trip's fare
  /// and tip alongside its "Biaya Admin Grab" expense) nets out to the
  /// real bottom line instead of just summing every amount regardless of
  /// sign.
  double get totalAmount =>
      transactions.fold(0.0, (sum, t) => sum + (t.type == TxType.income ? t.amount : -t.amount));
}

/// [transactions] must already be sorted (typically newest first).
List<DisplayEntry> groupTransactions(List<TransactionModel> transactions) {
  final Map<String, List<TransactionModel>> grouped = {};
  for (final t in transactions) {
    if (t.groupId != null) {
      grouped.putIfAbsent(t.groupId!, () => []).add(t);
    }
  }

  final result = <DisplayEntry>[];
  final seenGroups = <String>{};
  for (final t in transactions) {
    if (t.groupId != null) {
      if (seenGroups.contains(t.groupId)) continue;
      seenGroups.add(t.groupId!);
      result.add(DisplayEntry(grouped[t.groupId]!));
    } else {
      result.add(DisplayEntry([t]));
    }
  }
  return result;
}
