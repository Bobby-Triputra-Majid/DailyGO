import 'package:flutter/foundation.dart';
import '../data/hive_boxes.dart';
import '../models/category_model.dart';
import '../models/debt_model.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../utils/date_period.dart';
import 'finance_provider.dart';

/// Tracks utang/piutang (debt/receivable), kept separate from the
/// income/expense ledger so Saldo and Laporan only reflect money actually
/// earned or spent, not money just owed. A debt only turns into a real
/// transaction once it's marked Lunas (paid off).
class AssetProvider extends ChangeNotifier {
  /// Tells listeners to rebuild without changing anything itself — used
  /// after a bulk restore (e.g. importing a backup) writes straight into
  /// Hive, bypassing the usual add/update/delete methods.
  void refresh() {
    _sortedDebtsCache = null;
    notifyListeners();
  }

  // Same reasoning as FinanceProvider's transaction cache: debts is read
  // several times per build (unpaid, by-person, totals, ...), so the sort
  // is cached and invalidated only by the write methods below.
  List<DebtModel>? _sortedDebtsCache;

  List<DebtModel> get debts {
    return _sortedDebtsCache ??= (HiveBoxes.debts.values.toList()..sort((a, b) => b.date.compareTo(a.date)));
  }

  List<DebtModel> get unpaidDebts => debts.where((d) => !d.isPaid).toList();

  /// All debt records for one person (matched case/whitespace-insensitively),
  /// newest first.
  List<DebtModel> debtsForPerson(String personName) {
    final key = personName.trim().toLowerCase();
    return debts.where((d) => d.personName.trim().toLowerCase() == key).toList();
  }

  /// Debts grouped into one bubble per person, so someone with several
  /// records (e.g. borrowed on different days) shows up once instead of
  /// as separate rows. People with something still unpaid are listed
  /// first, then alphabetically.
  List<DebtPersonSummary> get debtsByPerson {
    final grouped = <String, List<DebtModel>>{};
    for (final d in debts) {
      grouped.putIfAbsent(d.personName.trim().toLowerCase(), () => []).add(d);
    }
    final list = grouped.values.map((entries) => DebtPersonSummary(entries)).toList();
    list.sort((a, b) {
      if (a.hasUnpaid != b.hasUnpaid) return a.hasUnpaid ? -1 : 1;
      return a.personName.toLowerCase().compareTo(b.personName.toLowerCase());
    });
    return list;
  }

  /// Distinct, alphabetically-sorted person names seen so far — used to
  /// let the user quickly pick an existing person instead of retyping
  /// (and risking a typo that would create a separate, unmerged group).
  List<String> get knownPersonNames {
    final names = debtsByPerson.map((p) => p.personName).toList();
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  double get totalReceivable => unpaidDebts
      .where((d) => d.direction == DebtDirection.theyOweMe)
      .fold(0.0, (s, d) => s + d.remaining);

  double get totalPayable => unpaidDebts
      .where((d) => d.direction == DebtDirection.iOweThem)
      .fold(0.0, (s, d) => s + d.remaining);

  String _generateId() => '${DateTime.now().microsecondsSinceEpoch}_${_counter++}';
  int _counter = 0;

  Future<DebtModel> addDebt({
    required String personName,
    required double amount,
    required DebtDirection direction,
    required DateTime date,
    String? note,
  }) async {
    final debt = DebtModel(
      id: _generateId(),
      personName: personName,
      amount: amount,
      direction: direction,
      date: date,
      note: note,
    );
    await HiveBoxes.debts.put(debt.id, debt);
    _sortedDebtsCache = null;
    notifyListeners();
    return debt;
  }

  Future<void> updateDebt(DebtModel debt) async {
    await HiveBoxes.debts.put(debt.id, debt);
    _sortedDebtsCache = null;
    notifyListeners();
  }

  /// Deletes a debt record. [financeProvider], when given, also removes
  /// every payment transaction ever booked for it — otherwise those
  /// "Pelunasan"/"Pembayaran" entries would keep showing up in Riwayat
  /// Transaksi and Beranda after the debt itself is gone.
  Future<void> deleteDebt(String id, [FinanceProvider? financeProvider]) async {
    if (financeProvider != null) {
      final debt = HiveBoxes.debts.get(id);
      if (debt != null) {
        for (final txId in debt.settlementTransactionIds) {
          await financeProvider.deleteTransaction(txId);
        }
      }
    }
    await HiveBoxes.debts.delete(id);
    _sortedDebtsCache = null;
    notifyListeners();
  }

  /// Deletes every debt record for one person at once — used when the
  /// whole bubble is swiped away from the Piutang list. See [deleteDebt]
  /// for why [financeProvider] matters.
  Future<void> deletePersonDebts(String personName, [FinanceProvider? financeProvider]) async {
    final matching = debtsForPerson(personName);
    if (financeProvider != null) {
      for (final d in matching) {
        for (final txId in d.settlementTransactionIds) {
          await financeProvider.deleteTransaction(txId);
        }
      }
    }
    for (final d in matching) {
      await HiveBoxes.debts.delete(d.id);
    }
    _sortedDebtsCache = null;
    notifyListeners();
  }

  /// Marks a debt as fully paid off in one go — just pays whatever is
  /// still [DebtModel.remaining].
  Future<void> markDebtPaid(DebtModel debt, FinanceProvider financeProvider, {String walletId = kWalletCash}) {
    return payDebt(debt, debt.remaining, financeProvider, walletId: walletId);
  }

  /// Books a payment toward a debt — the full remaining balance, or only
  /// part of it (e.g. owed Rp100.000, pays Rp70.000 now, Rp30.000 stays
  /// owed). If it was money owed *to* the user, this books an income
  /// transaction ("Pelunasan"/"Pembayaran"); if the user owed someone
  /// else, an expense — either way it's the first time this money is
  /// recognised as actually changing hands. [amount] is clamped to what's
  /// actually still owed, and amounts that pay it off fully mark it Lunas.
  /// [walletId] defaults to Cash since there's no wallet picker for this
  /// yet — without it, the payment would reduce Saldo but never show up
  /// in any dompet's balance/history.
  Future<void> payDebt(DebtModel debt, double amount, FinanceProvider financeProvider, {String walletId = kWalletCash}) async {
    if (debt.isPaid || amount <= 0) return;
    final payment = amount > debt.remaining ? debt.remaining : amount;
    final isFullPayment = payment >= debt.remaining;
    final paidAt = nowWib();

    final tx = TransactionModel(
      id: financeProvider.generateId(),
      type: debt.direction == DebtDirection.theyOweMe ? TxType.income : TxType.expense,
      amount: payment,
      categoryId: debt.direction == DebtDirection.theyOweMe ? 'piutang_lunas' : 'bayar_utang',
      date: paidAt,
      note: debt.direction == DebtDirection.theyOweMe
          ? (isFullPayment ? 'Pelunasan dari ${debt.personName}' : 'Pembayaran sebagian dari ${debt.personName}')
          : (isFullPayment ? 'Pelunasan ke ${debt.personName}' : 'Pembayaran sebagian ke ${debt.personName}'),
      walletId: walletId,
    );
    await financeProvider.addTransaction(tx);

    debt.paidAmount += payment;
    debt.settlementTransactionIds = [...debt.settlementTransactionIds, tx.id];
    if (isFullPayment) {
      debt.isPaid = true;
      debt.paidDate = paidAt;
    }
    await HiveBoxes.debts.put(debt.id, debt);
    _sortedDebtsCache = null;
    notifyListeners();
  }
}

/// A read-only view combining every debt record that belongs to one
/// person, for the grouped "one bubble per person" list.
class DebtPersonSummary {
  final List<DebtModel> entries;

  DebtPersonSummary(this.entries);

  String get personName => entries.first.personName;
  bool get hasUnpaid => entries.any((d) => !d.isPaid);

  double get unpaidReceivable => entries
      .where((d) => !d.isPaid && d.direction == DebtDirection.theyOweMe)
      .fold(0.0, (s, d) => s + d.remaining);

  double get unpaidPayable => entries
      .where((d) => !d.isPaid && d.direction == DebtDirection.iOweThem)
      .fold(0.0, (s, d) => s + d.remaining);

  double get net => unpaidReceivable - unpaidPayable;
}
