import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../data/hive_boxes.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';

/// Tracks dompet (wallet) balances — where money physically or virtually
/// sits (Cash, Saldo Grab, Bank, ...). A wallet never stores its own
/// balance; it's always derived by summing every transaction tagged with
/// that wallet's id, income minus expense — transfers included, since
/// those are exactly what move money between wallets.
class WalletProvider extends ChangeNotifier {
  int _counter = 0;
  String _generateId() => 'wallet_${DateTime.now().microsecondsSinceEpoch}_${_counter++}';
  static const String _adminFeesKey = 'adminFeesByRoute';

  String _routeKey(String fromId, String toId) => '$fromId>$toId';

  Map<String, double> get _adminFeesRaw {
    final stored = HiveBoxes.settings.get(_adminFeesKey, defaultValue: const <dynamic, dynamic>{}) as Map;
    return stored.map((k, v) => MapEntry(k as String, (v as num).toDouble()));
  }

  /// The default admin fee for moving money from [fromId] to [toId] —
  /// e.g. Bank -> OVO might always cost Rp1.000 while Saldo Grab -> Bank
  /// costs Rp500. 0 when no default has been set for that exact pair.
  double adminFeeFor(String fromId, String toId) => _adminFeesRaw[_routeKey(fromId, toId)] ?? 0.0;

  /// Sets (or, for 0/negative, clears) the default admin fee for one
  /// dompet pair, kept editable in Pengaturan.
  Future<void> setAdminFeeFor(String fromId, String toId, double value) async {
    final map = _adminFeesRaw;
    final key = _routeKey(fromId, toId);
    if (value <= 0) {
      map.remove(key);
    } else {
      map[key] = value;
    }
    await HiveBoxes.settings.put(_adminFeesKey, map);
    notifyListeners();
  }

  /// Every dompet pair with a configured default fee, for listing in
  /// Pengaturan.
  List<(String fromId, String toId, double fee)> get configuredAdminFees {
    final list = <(String, String, double)>[];
    for (final entry in _adminFeesRaw.entries) {
      final parts = entry.key.split('>');
      if (parts.length == 2) list.add((parts[0], parts[1], entry.value));
    }
    return list;
  }

  List<WalletModel> get wallets {
    final list = HiveBoxes.wallets.values.toList();
    list.sort((a, b) {
      if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  WalletModel? byId(String id) => HiveBoxes.wallets.get(id);

  /// Every transaction ever recorded against [walletId] — untreated by
  /// FinanceProvider's income/expense totals (which deliberately skip
  /// transfers), since a wallet balance needs those included.
  double balanceFor(String walletId) {
    var sum = 0.0;
    for (final t in HiveBoxes.transactions.values) {
      if (t.walletId != walletId) continue;
      sum += t.type == TxType.income ? t.amount : -t.amount;
    }
    return sum;
  }

  /// Sum of every wallet's balance — should always equal the dashboard's
  /// all-time Saldo, since every transaction is tagged with exactly one
  /// wallet and transfer legs cancel out across wallets.
  double get totalAcrossWallets => wallets.fold(0.0, (s, w) => s + balanceFor(w.id));

  /// History for one wallet — both ordinary transactions and transfer
  /// legs, newest first, so "Riwayat Dompet" can show everything that
  /// moved money in or out.
  List<TransactionModel> historyFor(String walletId) {
    final list = HiveBoxes.transactions.values.where((t) => t.walletId == walletId).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<WalletModel> addWallet(String name) async {
    final wallet = WalletModel(id: _generateId(), name: name.trim());
    await HiveBoxes.wallets.put(wallet.id, wallet);
    notifyListeners();
    return wallet;
  }

  Future<void> renameWallet(String id, String newName) async {
    final wallet = HiveBoxes.wallets.get(id);
    if (wallet == null) return;
    wallet.name = newName.trim();
    await wallet.save();
    notifyListeners();
  }

  /// Lets the user pick an image from their device (e.g. OVO/DANA/bank
  /// app icon) to use as this dompet's logo instead of the generic icon.
  /// Saved under the app's own documents directory so it survives
  /// restarts; any previous logo file for this dompet is removed first
  /// so old images don't pile up on-device. Returns false if nothing was
  /// picked.
  Future<bool> pickWalletImage(String walletId) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final picked = result?.files.single;
    if (picked?.bytes == null) return false;

    final wallet = HiveBoxes.wallets.get(walletId);
    if (wallet == null) return false;

    final docsDir = await getApplicationDocumentsDirectory();
    final logosDir = Directory('${docsDir.path}/wallet_logos');
    if (!await logosDir.exists()) await logosDir.create(recursive: true);

    if (wallet.imagePath != null) {
      final old = File(wallet.imagePath!);
      if (await old.exists()) await old.delete();
    }

    final ext = picked!.extension ?? 'png';
    final file = File('${logosDir.path}/$walletId.$ext');
    await file.writeAsBytes(picked.bytes!, flush: true);

    wallet.imagePath = file.path;
    await wallet.save();
    notifyListeners();
    return true;
  }

  /// Removes this dompet's logo image, falling back to the generic icon.
  Future<void> clearWalletImage(String walletId) async {
    final wallet = HiveBoxes.wallets.get(walletId);
    if (wallet == null || wallet.imagePath == null) return;
    final old = File(wallet.imagePath!);
    if (await old.exists()) await old.delete();
    wallet.imagePath = null;
    await wallet.save();
    notifyListeners();
  }

  bool walletInUse(String id) {
    return HiveBoxes.transactions.values.any((t) => t.walletId == id);
  }

  /// Only a custom (non-default) wallet with no transaction history can
  /// be deleted — Cash/Saldo Grab/Bank are assumed to exist by Grab trip
  /// entry, and deleting a wallet still in use would orphan its history.
  Future<bool> deleteWallet(String id) async {
    final wallet = HiveBoxes.wallets.get(id);
    if (wallet == null || wallet.isDefault || walletInUse(id)) return false;
    await HiveBoxes.wallets.delete(id);
    notifyListeners();
    return true;
  }

  /// Tells listeners to rebuild without changing anything itself — used
  /// after a bulk restore (e.g. importing a backup) writes straight into
  /// Hive, bypassing the usual add/update/delete methods.
  void refresh() => notifyListeners();
}
