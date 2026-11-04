import 'package:flutter/foundation.dart';
import '../data/hive_boxes.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../utils/date_period.dart';

/// Grab guarantees a minimum payout per trip. If what's billed to the
/// customer is less than this, the system tops the driver's fare up to
/// this amount on its own — it isn't a "bonus", it's just the floor fare.
const double kGrabMinimumFare = 8000;

/// Default price of one "ke kampus" (to campus) trip, used until the
/// user sets their own in Pengaturan.
const double kDefaultHargaKeKampus = 5000;

/// Default price of the "telur" (egg) add-on on a meal, used until the
/// user sets their own in Pengaturan.
const double kDefaultHargaTelur = 1500;

class FinanceProvider extends ChangeNotifier {
  int _counter = 0;
  static const String _hargaKeKampusKey = 'hargaKeKampus';
  static const String _hargaTelurKey = 'hargaTelur';
  static const String _aktifKeKampusKey = 'aktifKeKampus';
  static const String _aktifCatatMakanKey = 'aktifCatatMakan';

  String generateId() => '${DateTime.now().microsecondsSinceEpoch}_${_counter++}';

  /// Tells listeners to rebuild without changing anything itself — used
  /// after a bulk restore (e.g. importing a backup) writes straight into
  /// Hive, bypassing the usual add/update/delete methods.
  void refresh() {
    _sortedTransactionsCache = null;
    notifyListeners();
  }

  // A single build can call allTransactions several times (totals, recent
  // list, category breakdown, ...). Re-sorting the full Hive box every
  // single time gets noticeably slow once there's months of history, so
  // the sorted list is cached and only rebuilt when the data actually
  // changes (every write method below clears it before notifying).
  List<TransactionModel>? _sortedTransactionsCache;

  List<CategoryModel> get categories => HiveBoxes.categories.values.toList();

  List<CategoryModel> categoriesOfType(TxType type) {
    final list = categories.where((c) => c.type == type).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  CategoryModel? categoryById(String id) {
    for (final c in HiveBoxes.categories.values) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<TransactionModel> get allTransactions {
    return _sortedTransactionsCache ??= (HiveBoxes.transactions.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date)));
  }

  List<TransactionModel> transactionsInRange(
    PeriodRange range, {
    TxType? type,
    String? categoryId,
    String? excludeGroupLabel,
    bool includeTransfers = false,
  }) {
    return allTransactions.where((t) {
      if (!range.contains(t.date)) return false;
      if (type != null && t.type != type) return false;
      if (categoryId != null && t.categoryId != categoryId) return false;
      if (excludeGroupLabel != null && t.groupLabel == excludeGroupLabel) return false;
      // A dompet-to-dompet transfer leg is never real income/expense, so
      // every list/total built on this skips it unless asked otherwise.
      if (!includeTransfers && t.isTransfer) return false;
      return true;
    }).toList();
  }

  double totalForType(PeriodRange range, TxType type, {String? excludeGroupLabel}) {
    return transactionsInRange(range, type: type, excludeGroupLabel: excludeGroupLabel).fold(0.0, (sum, t) => sum + t.amount);
  }

  double balanceFor(PeriodRange range) {
    return totalForType(range, TxType.income) - totalForType(range, TxType.expense);
  }

  /// Sum of [type] across every transaction ever recorded, ignoring the
  /// period selector — used for Saldo, which should carry forward across
  /// months instead of resetting whenever the dashboard's period changes.
  double totalAllTime(TxType type, {String? excludeGroupLabel}) {
    return allTransactions.where((t) {
      if (t.type != type) return false;
      if (excludeGroupLabel != null && t.groupLabel == excludeGroupLabel) return false;
      if (t.isTransfer) return false;
      return true;
    }).fold(0.0, (sum, t) => sum + t.amount);
  }

  Map<CategoryModel, double> categoryBreakdown(PeriodRange range, TxType type, {String? excludeGroupLabel}) {
    final totals = <String, double>{};
    for (final t in transactionsInRange(range, type: type, excludeGroupLabel: excludeGroupLabel)) {
      totals[t.categoryId] = (totals[t.categoryId] ?? 0) + t.amount;
    }
    final result = <CategoryModel, double>{};
    totals.forEach((catId, total) {
      final cat = categoryById(catId);
      if (cat != null) result[cat] = total;
    });
    final entries = result.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(entries);
  }

  Future<void> addTransaction(TransactionModel tx) async {
    await HiveBoxes.transactions.put(tx.id, tx);
    _sortedTransactionsCache = null;
    notifyListeners();
  }

  Future<void> updateTransaction(TransactionModel tx) async {
    await HiveBoxes.transactions.put(tx.id, tx);
    _sortedTransactionsCache = null;
    notifyListeners();
  }

  Future<void> deleteTransaction(String id) async {
    await HiveBoxes.transactions.delete(id);
    _sortedTransactionsCache = null;
    notifyListeners();
  }

  Future<void> deleteGroup(String groupId) async {
    final ids = HiveBoxes.transactions.values
        .where((t) => t.groupId == groupId)
        .map((t) => t.id)
        .toList();
    for (final id in ids) {
      await HiveBoxes.transactions.delete(id);
    }
    _sortedTransactionsCache = null;
    notifyListeners();
  }

  /// Works out what actually gets booked as "Ongkos Grab" income and as
  /// Tip, given what was billed vs what was actually received. Shared by
  /// [addGrabTrip]/[updateGrabTrip] and the trip entry screen's live
  /// preview, so both always agree.
  ///
  /// Tip/shortage is always about physical cash, so it's worked out from
  /// [billedAmount] vs [receivedAmount] regardless of [netPayout]:
  /// - If the customer paid at least the billed amount: anything paid
  ///   beyond the billed amount is Tip.
  /// - If the customer paid *less* than billed (a shortage — allowed, it
  ///   happens): there's no Tip.
  ///
  /// The fare itself is a separate question. Normally it's just
  /// [billedAmount] (or [receivedAmount] plus top-up on a shortage)
  /// floored to [kGrabMinimumFare]. But sometimes — typically on a cash
  /// trip — Grab's system credits less than that, e.g. billed 16.000,
  /// passenger hands over 17.000 cash, yet the system only pays out
  /// 14.000 as the fare. The cash itself was still fully collected by the
  /// driver though — the gap is Grab's commission, deducted separately
  /// from Saldo Grab as a "Biaya Admin Grab" expense (see
  /// [_adminFeeAmount]), not subtracted from the fare/cash here.
  static (double fare, double tip) resolveFareAndTip(
    double billedAmount,
    double receivedAmount,
  ) {
    final isShortage = receivedAmount < billedAmount;
    final tip = isShortage ? 0.0 : receivedAmount - billedAmount;
    if (isShortage) {
      final topUp = billedAmount < kGrabMinimumFare ? kGrabMinimumFare - billedAmount : 0.0;
      return (receivedAmount + topUp, 0.0);
    }
    final fare = billedAmount < kGrabMinimumFare ? kGrabMinimumFare : billedAmount;
    return (fare, tip);
  }

  /// Which dompet a cash trip's fare/tip lands in — always Cash, since
  /// both are physical money (the fare amount actually recognized by
  /// Grab, plus whatever extra cash was handed over as tip).
  /// A non-tunai trip's fare isn't physical cash yet — it sits in Grab's
  /// own ledger until withdrawn. An offline trip never goes through
  /// Grab's own ledger at all — its non-tunai leg (e.g. a bank transfer
  /// straight from the passenger) lands directly in Bank instead.
  String _fareWalletId(bool isCash, {bool isOffline = false}) {
    if (isCash) return kWalletCash;
    return isOffline ? kWalletBank : kWalletSaldoGrab;
  }

  /// Which dompet a trip's Tip (when kept separate from the fare) lands
  /// in. A cash trip's tip is always physical Cash. For Non-Tunai/Offline,
  /// [tipIsCash] says whether it was actually handed over as cash instead
  /// of through whatever channel the fare itself used — Saldo Grab for an
  /// in-app Non-Tunai trip, Bank for an Offline one (same as the fare,
  /// since neither goes through Grab's own ledger).
  String _tipWalletId(bool isCash, bool tipIsCash, {bool isOffline = false}) {
    if (isCash || tipIsCash) return kWalletCash;
    return isOffline ? kWalletBank : kWalletSaldoGrab;
  }

  /// Only non-zero on a *cash* trip with a known system cut: Grab's
  /// commission on this trip, the part of the billed amount the
  /// passenger's cash covered but Grab's system doesn't credit as net
  /// fare. The cash itself was still fully collected by the driver, so
  /// this is booked as a real expense (not subtracted from the fare),
  /// deducted from Saldo Grab since that's the account Grab actually
  /// takes its cut from, separate from the cash in hand.
  double _adminFeeAmount(bool isCash, double billedAmount, double? netPayoutAmount) {
    if (!isCash || netPayoutAmount == null) return 0;
    final diff = billedAmount - netPayoutAmount;
    return diff > 0 ? diff : 0;
  }

  /// Only non-zero on a *cash* trip billed below [kGrabMinimumFare]: the
  /// part of the recognized fare that's Grab's own top-up, not cash the
  /// passenger actually handed over. e.g. billed 7.000, passenger pays
  /// exactly that — Grab still credits 8.000 as "Ongkos Grab", but only
  /// 7.000 of that is real cash in the driver's pocket; the other 1.000
  /// is a pending digital credit, so it's booked to Saldo Grab instead of
  /// Cash. Never applies to Non-Tunai/Offline — their whole fare already
  /// sits in one dompet (Saldo Grab/Bank) with no cash-vs-digital split
  /// to make.
  double _minimumFareTopUp(bool isCash, double billedAmount) {
    if (!isCash) return 0;
    final diff = kGrabMinimumFare - billedAmount;
    return diff > 0 ? diff : 0;
  }

  /// Records a Grab trip. All rows share a groupId so the UI can show
  /// them as one trip — returned so a caller can tag anything else
  /// derived from this same trip (e.g. a "Pisahkan Koin" transfer) with
  /// it too, so deleting the trip cleans that up as well. See
  /// [resolveFareAndTip] for how the fare/tip split is worked out, and
  /// [_adminFeeAmount] for the Grab commission expense on a cash trip
  /// with a known system cut.
  Future<String> addGrabTrip({
    required double fareAmount,
    required double receivedAmount,
    required DateTime date,
    required bool isCash,
    String? note,
    double? netPayoutAmount,
    bool tipIsCash = true,
    bool isOffline = false,
  }) async {
    final groupId = generateId();
    // An offline trip (flagged down outside the app) never goes through
    // Grab's own billing — no minimum-fare top-up, no system cut — but
    // still has a Tip, taken as whatever was received above the fare.
    final (effectiveFare, tipAmount) = isOffline
        ? (fareAmount, (receivedAmount - fareAmount).clamp(0.0, double.infinity))
        : resolveFareAndTip(fareAmount, receivedAmount);
    // Measured against the fare actually booked (which, on a shortage, is
    // topped up above the raw billed amount), not the raw billed amount
    // itself, so a shortage and a known commission on the same trip don't
    // overstate the commission.
    final adminFee = isOffline ? 0.0 : _adminFeeAmount(isCash, effectiveFare, netPayoutAmount);
    // Measured against the raw billed amount — a cash trip billed below
    // the minimum fare gets its "Ongkos Grab" topped up to the floor, but
    // only the billed portion is real cash; the top-up is Grab's own
    // credit, not something the passenger handed over.
    final topUp = isOffline ? 0.0 : _minimumFareTopUp(isCash, fareAmount);

    final fareTx = TransactionModel(
      id: generateId(),
      type: TxType.income,
      amount: effectiveFare - topUp,
      categoryId: 'grab',
      date: date,
      note: note,
      groupId: groupId,
      groupLabel: 'Trip Grab',
      isCash: isCash,
      billedAmount: fareAmount,
      receivedAmount: receivedAmount,
      netPayoutAmount: netPayoutAmount,
      walletId: _fareWalletId(isCash, isOffline: isOffline),
      isOffline: isOffline,
    );
    await HiveBoxes.transactions.put(fareTx.id, fareTx);

    if (topUp > 0) {
      final topUpTx = TransactionModel(
        id: generateId(),
        type: TxType.income,
        amount: topUp,
        categoryId: 'grab',
        date: date,
        note: 'Subsidi minimum ongkos Grab (bukan cash fisik)',
        groupId: groupId,
        groupLabel: 'Trip Grab',
        walletId: kWalletSaldoGrab,
      );
      await HiveBoxes.transactions.put(topUpTx.id, topUpTx);
    }

    if (tipAmount > 0) {
      final tipTx = TransactionModel(
        id: generateId(),
        type: TxType.income,
        amount: tipAmount,
        categoryId: 'tip',
        date: date,
        note: 'Tip dari trip Grab',
        groupId: groupId,
        groupLabel: 'Trip Grab',
        walletId: _tipWalletId(isCash, tipIsCash, isOffline: isOffline),
      );
      await HiveBoxes.transactions.put(tipTx.id, tipTx);
    }

    if (adminFee > 0) {
      final adminTx = TransactionModel(
        id: generateId(),
        type: TxType.expense,
        amount: adminFee,
        categoryId: 'biaya_admin',
        date: date,
        note: 'Komisi/biaya admin Grab',
        groupId: groupId,
        groupLabel: 'Trip Grab',
        walletId: kWalletSaldoGrab,
      );
      await HiveBoxes.transactions.put(adminTx.id, adminTx);
    }
    _sortedTransactionsCache = null;
    notifyListeners();
    return groupId;
  }

  /// Updates a trip recorded by [addGrabTrip], keeping its id/groupId so
  /// it stays the same row in the UI. The tip and admin-fee rows are
  /// created, updated, or removed as needed depending on whether they
  /// still apply after the edit.
  Future<void> updateGrabTrip({
    required TransactionModel existingFare,
    required String groupId,
    TransactionModel? existingTip,
    TransactionModel? existingAdminFee,
    TransactionModel? existingTopUp,
    required double fareAmount,
    required double receivedAmount,
    required DateTime date,
    required bool isCash,
    String? note,
    double? netPayoutAmount,
    bool tipIsCash = true,
    bool isOffline = false,
  }) async {
    final (effectiveFare, tipAmount) = isOffline
        ? (fareAmount, (receivedAmount - fareAmount).clamp(0.0, double.infinity))
        : resolveFareAndTip(fareAmount, receivedAmount);
    final adminFee = isOffline ? 0.0 : _adminFeeAmount(isCash, effectiveFare, netPayoutAmount);
    final topUp = isOffline ? 0.0 : _minimumFareTopUp(isCash, fareAmount);

    existingFare
      ..amount = effectiveFare - topUp
      ..date = date
      ..note = note
      ..isCash = isCash
      ..billedAmount = fareAmount
      ..receivedAmount = receivedAmount
      ..netPayoutAmount = netPayoutAmount
      ..walletId = _fareWalletId(isCash, isOffline: isOffline)
      ..isOffline = isOffline;
    await HiveBoxes.transactions.put(existingFare.id, existingFare);

    if (topUp > 0) {
      if (existingTopUp != null) {
        existingTopUp
          ..amount = topUp
          ..date = date;
        await HiveBoxes.transactions.put(existingTopUp.id, existingTopUp);
      } else {
        final topUpTx = TransactionModel(
          id: generateId(),
          type: TxType.income,
          amount: topUp,
          categoryId: 'grab',
          date: date,
          note: 'Subsidi minimum ongkos Grab (bukan cash fisik)',
          groupId: groupId,
          groupLabel: 'Trip Grab',
          walletId: kWalletSaldoGrab,
        );
        await HiveBoxes.transactions.put(topUpTx.id, topUpTx);
      }
    } else if (existingTopUp != null) {
      await HiveBoxes.transactions.delete(existingTopUp.id);
    }

    if (tipAmount > 0) {
      final tipWalletId = _tipWalletId(isCash, tipIsCash, isOffline: isOffline);
      if (existingTip != null) {
        existingTip
          ..amount = tipAmount
          ..date = date
          ..walletId = tipWalletId;
        await HiveBoxes.transactions.put(existingTip.id, existingTip);
      } else {
        final tipTx = TransactionModel(
          id: generateId(),
          type: TxType.income,
          amount: tipAmount,
          categoryId: 'tip',
          date: date,
          note: 'Tip dari trip Grab',
          groupId: groupId,
          groupLabel: 'Trip Grab',
          walletId: tipWalletId,
        );
        await HiveBoxes.transactions.put(tipTx.id, tipTx);
      }
    } else if (existingTip != null) {
      await HiveBoxes.transactions.delete(existingTip.id);
    }

    if (adminFee > 0) {
      if (existingAdminFee != null) {
        existingAdminFee
          ..amount = adminFee
          ..date = date;
        await HiveBoxes.transactions.put(existingAdminFee.id, existingAdminFee);
      } else {
        final adminTx = TransactionModel(
          id: generateId(),
          type: TxType.expense,
          amount: adminFee,
          categoryId: 'biaya_admin',
          date: date,
          note: 'Komisi/biaya admin Grab',
          groupId: groupId,
          groupLabel: 'Trip Grab',
          walletId: kWalletSaldoGrab,
        );
        await HiveBoxes.transactions.put(adminTx.id, adminTx);
      }
    } else if (existingAdminFee != null) {
      await HiveBoxes.transactions.delete(existingAdminFee.id);
    }
    _sortedTransactionsCache = null;
    notifyListeners();
  }

  /// Moves money between two dompets — e.g. "Tarik Saldo Grab" to a bank
  /// account. Both legs move the same [amount] (so the transfer itself
  /// never creates or destroys money) and are tagged [isTransfer] so they
  /// never count as income/expense anywhere. A real cost tied to the
  /// transfer (e.g. the bank's admin fee) is booked separately as an
  /// ordinary expense from [toWalletId], since that's genuinely money
  /// lost, not money that just changed location.
  ///
  /// [groupId]/[groupLabel] default to a fresh standalone "Transfer
  /// Dompet" — pass the originating trip's own groupId (and groupLabel
  /// 'Trip Grab') instead when this transfer is really just part of that
  /// trip (e.g. "Pisahkan Koin" splitting cash just collected into coin
  /// wallets), so deleting the trip deletes this leg too instead of
  /// leaving an orphaned transfer behind.
  Future<void> transferBetweenWallets({
    required String fromWalletId,
    required String toWalletId,
    required double amount,
    required DateTime date,
    String? note,
    double adminFee = 0,
    String? groupId,
    String? groupLabel,
  }) async {
    final effectiveGroupId = groupId ?? generateId();
    final effectiveGroupLabel = groupLabel ?? 'Transfer Dompet';
    final outTx = TransactionModel(
      id: generateId(),
      type: TxType.expense,
      amount: amount,
      categoryId: 'transfer',
      date: date,
      note: note,
      groupId: effectiveGroupId,
      groupLabel: effectiveGroupLabel,
      walletId: fromWalletId,
      isTransfer: true,
    );
    final inTx = TransactionModel(
      id: generateId(),
      type: TxType.income,
      amount: amount,
      categoryId: 'transfer',
      date: date,
      note: note,
      groupId: effectiveGroupId,
      groupLabel: effectiveGroupLabel,
      walletId: toWalletId,
      isTransfer: true,
    );
    await HiveBoxes.transactions.put(outTx.id, outTx);
    await HiveBoxes.transactions.put(inTx.id, inTx);

    if (adminFee > 0) {
      final feeTx = TransactionModel(
        id: generateId(),
        type: TxType.expense,
        amount: adminFee,
        categoryId: 'biaya_admin',
        date: date,
        note: 'Biaya admin transfer',
        groupId: effectiveGroupId,
        groupLabel: effectiveGroupLabel,
        walletId: toWalletId,
      );
      await HiveBoxes.transactions.put(feeTx.id, feeTx);
    }
    _sortedTransactionsCache = null;
    notifyListeners();
  }

  /// Price of one "ke kampus" trip, settable in Pengaturan so it's easy
  /// to update if the price changes.
  double get hargaKeKampus =>
      (HiveBoxes.settings.get(_hargaKeKampusKey, defaultValue: kDefaultHargaKeKampus) as num).toDouble();

  Future<void> setHargaKeKampus(double value) async {
    await HiveBoxes.settings.put(_hargaKeKampusKey, value);
    notifyListeners();
  }

  /// Price of the "telur" (egg) add-on on a Grab trip's meal expense,
  /// settable in Pengaturan so it's easy to update if the price changes.
  double get hargaTelur =>
      (HiveBoxes.settings.get(_hargaTelurKey, defaultValue: kDefaultHargaTelur) as num).toDouble();

  Future<void> setHargaTelur(double value) async {
    await HiveBoxes.settings.put(_hargaTelurKey, value);
    notifyListeners();
  }

  /// Whether the "Ke Kampus" option shows up on the Isi BBM Grab screen —
  /// off (e.g. during semester break) hides it there entirely instead of
  /// just leaving it unchecked. On by default.
  bool get aktifKeKampus => (HiveBoxes.settings.get(_aktifKeKampusKey, defaultValue: true) as bool);

  Future<void> setAktifKeKampus(bool value) async {
    await HiveBoxes.settings.put(_aktifKeKampusKey, value);
    notifyListeners();
  }

  /// Whether the "Catat Makan" options show up on the Grab tab/trip entry
  /// — off hides the quick-add UI entirely (existing Makan records are
  /// unaffected either way). On by default.
  bool get aktifCatatMakan => (HiveBoxes.settings.get(_aktifCatatMakanKey, defaultValue: true) as bool);

  Future<void> setAktifCatatMakan(bool value) async {
    await HiveBoxes.settings.put(_aktifCatatMakanKey, value);
    notifyListeners();
  }

  /// Records a BBM Grab fill-up. Since fuel isn't necessarily topped up
  /// every day, [kampusCount] lets one fill-up cover several days' worth
  /// of "ke kampus" (to campus) trips at once: `kampusCount *
  /// hargaKeKampus` is split off and booked under the everyday "BBM"
  /// category — a fully separate transaction, so it shows as its own
  /// entry on Beranda like any personal expense — and the remainder is
  /// booked as "BBM Grab", shown on the Grab tab.
  Future<void> addGrabFuel({
    required double totalAmount,
    required DateTime date,
    int kampusCount = 0,
    String? note,
  }) async {
    final kampusAmount = (kampusCount * hargaKeKampus).clamp(0, totalAmount).toDouble();
    final grabAmount = totalAmount - kampusAmount;

    if (grabAmount > 0) {
      final tx = TransactionModel(
        id: generateId(),
        type: TxType.expense,
        amount: grabAmount,
        categoryId: 'bensin_grab',
        date: date,
        note: note,
        // Tagged like every other Grab-related transaction so Beranda's
        // "excludeGroupLabel: Trip Grab" filter hides it from the recent
        // list — it's already counted in Beranda's aggregated
        // "Pengeluaran Grab" row, so without this tag it showed up twice.
        groupLabel: 'Trip Grab',
        walletId: kWalletCash,
      );
      await HiveBoxes.transactions.put(tx.id, tx);
    }
    if (kampusAmount > 0) {
      final tx = TransactionModel(
        id: generateId(),
        type: TxType.expense,
        amount: kampusAmount,
        categoryId: 'bensin',
        date: date,
        note: kampusCount == 1 ? 'Ke kampus' : 'Ke kampus ($kampusCount hari)',
        walletId: kWalletCash,
      );
      await HiveBoxes.transactions.put(tx.id, tx);
    }
    _sortedTransactionsCache = null;
    notifyListeners();
  }

  Future<CategoryModel> addCategory({
    required String name,
    required TxType type,
    required int colorValue,
    required int iconCodePoint,
  }) async {
    final cat = CategoryModel(
      id: generateId(),
      name: name,
      type: type,
      colorValue: colorValue,
      iconCodePoint: iconCodePoint,
    );
    await HiveBoxes.categories.put(cat.id, cat);
    notifyListeners();
    return cat;
  }

  Future<void> updateCategory(CategoryModel cat) async {
    await HiveBoxes.categories.put(cat.id, cat);
    notifyListeners();
  }

  bool categoryInUse(String categoryId) {
    return HiveBoxes.transactions.values.any((t) => t.categoryId == categoryId);
  }

  Future<bool> deleteCategory(String id) async {
    if (categoryInUse(id)) return false;
    await HiveBoxes.categories.delete(id);
    notifyListeners();
    return true;
  }
}
