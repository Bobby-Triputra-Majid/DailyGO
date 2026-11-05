import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/category_model.dart';
import '../models/debt_model.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';

class HiveBoxes {
  static const String categoriesBoxName = 'categories';
  static const String transactionsBoxName = 'transactions';
  static const String debtsBoxName = 'debts';
  static const String settingsBoxName = 'settings';
  static const String walletsBoxName = 'wallets';

  static Box<CategoryModel> get categories => Hive.box<CategoryModel>(categoriesBoxName);
  static Box<TransactionModel> get transactions => Hive.box<TransactionModel>(transactionsBoxName);
  static Box<DebtModel> get debts => Hive.box<DebtModel>(debtsBoxName);
  static Box<WalletModel> get wallets => Hive.box<WalletModel>(walletsBoxName);

  /// Plain dynamic box for small app settings (e.g. dark mode, the price
  /// of a "ke kampus" trip) — no custom TypeAdapter needed for these.
  static Box get settings => Hive.box(settingsBoxName);

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(CategoryModelAdapter());
    Hive.registerAdapter(TransactionModelAdapter());
    Hive.registerAdapter(DebtModelAdapter());
    Hive.registerAdapter(WalletModelAdapter());
    await Hive.openBox<CategoryModel>(categoriesBoxName);
    await Hive.openBox<TransactionModel>(transactionsBoxName);
    await Hive.openBox<DebtModel>(debtsBoxName);
    await Hive.openBox<WalletModel>(walletsBoxName);
    await Hive.openBox(settingsBoxName);
    await _seedDefaults();
    await _seedWallets();
    await _migrateLegacyData();
  }

  /// The dompets every install starts with — 3 fixed ones Grab trip entry
  /// routes money to by id, plus the 2 coin-jar wallets "Pisahkan Koin"
  /// transfers into. Upsert-if-missing, like categories, so an app update
  /// can rely on these ids existing even on installs that already have
  /// data.
  static Future<void> _seedWallets() async {
    final defaults = [
      WalletModel(id: kWalletCash, name: 'Cash', isDefault: true),
      WalletModel(id: kWalletSaldoGrab, name: 'Saldo Grab', isDefault: true),
      WalletModel(id: kWalletBank, name: 'Bank', isDefault: true),
      WalletModel(id: kWalletLogam, name: 'Uang Logam', isDefault: false),
      WalletModel(id: kWalletGopek, name: 'Uang Gopek', isDefault: false),
    ];
    for (final w in defaults) {
      if (!wallets.containsKey(w.id)) {
        await wallets.put(w.id, w);
      }
    }
  }

  /// "BBM Grab" transactions used to be saved without a groupLabel, so
  /// Beranda's "Trip Grab" exclusion filter missed them — they showed up
  /// both as their own row and inside the aggregated "Pengeluaran Grab"
  /// row. New entries are tagged correctly already; this backfills
  /// existing ones so old data stops double-counting too.
  static Future<void> _migrateLegacyData() async {
    for (final tx in transactions.values) {
      var changed = false;
      if (tx.categoryId == 'bensin_grab' && tx.groupLabel == null) {
        tx.groupLabel = 'Trip Grab';
        changed = true;
      }
      // Every transaction needs a dompet now — records saved before the
      // dompet feature existed default to Cash, the one that was
      // implicitly true for all of them before wallets existed.
      if (tx.walletId == null) {
        tx.walletId = kWalletCash;
        changed = true;
      }
      if (changed) await tx.save();
    }
  }

  /// Adds any default category that doesn't exist yet (by id). Using
  /// upsert-if-missing instead of "only seed on an empty box" lets us add
  /// new default categories (e.g. 'grab_bonus') in app updates without
  /// losing them on installs that already have data.
  static Future<void> _seedDefaults() async {
    final defaults = <CategoryModel>[
      CategoryModel(
        id: 'grab',
        name: 'Grab',
        type: TxType.income,
        colorValue: 0xFF1565C0,
        iconCodePoint: Icons.local_taxi.codePoint,
        isDefault: true,
      ),
      CategoryModel(
        id: 'tip',
        name: 'Tip',
        type: TxType.income,
        colorValue: 0xFFF9A825,
        iconCodePoint: Icons.card_giftcard.codePoint,
        isDefault: true,
      ),
      CategoryModel(
        id: 'gaji',
        name: 'Gaji',
        type: TxType.income,
        colorValue: 0xFF2E7D32,
        iconCodePoint: Icons.work.codePoint,
        isDefault: true,
      ),
      CategoryModel(
        id: 'bonus',
        name: 'Bonus',
        type: TxType.income,
        colorValue: 0xFF6A1B9A,
        iconCodePoint: Icons.savings.codePoint,
        isDefault: true,
      ),
      CategoryModel(
        id: 'income_lain',
        name: 'Lainnya',
        type: TxType.income,
        colorValue: 0xFF37474F,
        iconCodePoint: Icons.attach_money.codePoint,
        isDefault: true,
      ),
      CategoryModel(
        id: 'bensin',
        name: 'BBM',
        type: TxType.expense,
        colorValue: 0xFFD84315,
        iconCodePoint: Icons.local_gas_station.codePoint,
        isDefault: true,
      ),
      CategoryModel(
        id: 'bensin_grab',
        name: 'BBM Grab',
        type: TxType.expense,
        colorValue: 0xFFC62828,
        iconCodePoint: Icons.local_gas_station.codePoint,
        isDefault: true,
      ),
      CategoryModel(
        id: 'makan',
        name: 'Makan',
        type: TxType.expense,
        colorValue: 0xFFF9A825,
        iconCodePoint: Icons.restaurant.codePoint,
        isDefault: true,
      ),
      CategoryModel(
        id: 'servis',
        name: 'Servis Kendaraan',
        type: TxType.expense,
        colorValue: 0xFF37474F,
        iconCodePoint: Icons.build.codePoint,
        isDefault: true,
      ),
      CategoryModel(
        id: 'pulsa',
        name: 'Pulsa/Data',
        type: TxType.expense,
        colorValue: 0xFF00897B,
        iconCodePoint: Icons.phone_android.codePoint,
        isDefault: true,
      ),
      CategoryModel(
        id: 'expense_lain',
        name: 'Lainnya',
        type: TxType.expense,
        colorValue: 0xFFAD1457,
        iconCodePoint: Icons.shopping_cart.codePoint,
        isDefault: true,
      ),
      CategoryModel(
        id: 'piutang_lunas',
        name: 'Pelunasan Piutang',
        type: TxType.income,
        colorValue: 0xFF00897B,
        iconCodePoint: Icons.handshake.codePoint,
        isDefault: true,
      ),
      CategoryModel(
        id: 'bayar_utang',
        name: 'Bayar Utang',
        type: TxType.expense,
        colorValue: 0xFF6A1B9A,
        iconCodePoint: Icons.handshake.codePoint,
        isDefault: true,
      ),
      // Booked once, the moment a piutang/utang record is created — not
      // counted as real income/expense (isTransfer skips it), but still
      // moves the chosen dompet's balance since cash really does leave
      // (piutang) or enter (utang) hand at that point.
      CategoryModel(
        id: 'piutang_keluar',
        name: 'Piutang Diberikan',
        type: TxType.expense,
        colorValue: 0xFF00897B,
        iconCodePoint: Icons.call_made.codePoint,
        isDefault: true,
      ),
      CategoryModel(
        id: 'utang_masuk',
        name: 'Utang Diterima',
        type: TxType.income,
        colorValue: 0xFF6A1B9A,
        iconCodePoint: Icons.call_received.codePoint,
        isDefault: true,
      ),
      // Used by both legs of a dompet-to-dompet transfer (e.g. "Tarik
      // Saldo Grab") — purely for icon/label when shown in Riwayat
      // Dompet; never counted as income/expense (isTransfer skips it).
      CategoryModel(
        id: 'transfer',
        name: 'Transfer Dompet',
        type: TxType.expense,
        colorValue: 0xFF455A64,
        iconCodePoint: Icons.swap_horiz.codePoint,
        isDefault: true,
      ),
      CategoryModel(
        id: 'biaya_admin',
        name: 'Biaya Admin',
        type: TxType.expense,
        colorValue: 0xFF795548,
        iconCodePoint: Icons.account_balance.codePoint,
        isDefault: true,
      ),
    ];

    for (final c in defaults) {
      if (!categories.containsKey(c.id)) {
        await categories.put(c.id, c);
      }
    }
  }
}
