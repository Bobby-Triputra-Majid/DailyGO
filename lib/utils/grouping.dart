import '../models/transaction_model.dart';

/// A single row to display in a transaction list. Transactions that share
/// a `groupId` (e.g. a Grab fare + its auto-detected tip) are collapsed
/// into one entry so they read as a single trip in the UI.
class DisplayEntry {
  final List<TransactionModel> transactions;

  DisplayEntry(this.transactions);

  bool get isGroup => transactions.length > 1;
  TransactionModel get primary => transactions.first;
  DateTime get date => primary.date;
  String? get groupLabel => primary.groupLabel;
  String? get groupId => primary.groupId;

  double get totalAmount => transactions.fold(0.0, (sum, t) => sum + t.amount);
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
