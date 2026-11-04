import 'package:hive/hive.dart';

/// Fixed ids for the 3 wallets every install starts with — Grab trip
/// entry routes money to [kWalletCash]/[kWalletSaldoGrab] by id directly,
/// so these specific wallets must always exist.
const String kWalletCash = 'cash';
const String kWalletSaldoGrab = 'saldo_grab';
const String kWalletBank = 'bank';

/// Coin-jar wallets — seeded automatically (so "Pisahkan Koin" on a Grab
/// trip always has somewhere to transfer to) but not [WalletModel.isDefault],
/// so they can be deleted like any other custom dompet if unused.
const String kWalletLogam = 'koin_logam';
const String kWalletGopek = 'koin_gopek';

/// Where money physically or virtually sits — Cash in hand, Grab's
/// not-yet-withdrawn ledger, a bank account, etc. A wallet's balance is
/// never stored directly; it's always derived by summing every
/// [TransactionModel] tagged with this wallet's [id].
class WalletModel extends HiveObject {
  String id;
  String name;

  /// Seeded wallets (Cash, Saldo Grab, Bank) can be renamed but not
  /// deleted, since Grab trip entry assumes they exist.
  bool isDefault;

  /// Absolute path to a user-picked logo image for this dompet (e.g. the
  /// OVO/DANA/bank logo), saved on-device by [WalletProvider.setWalletImage].
  /// Null falls back to the generic icon.
  String? imagePath;

  WalletModel({required this.id, required this.name, this.isDefault = false, this.imagePath});
}

class WalletModelAdapter extends TypeAdapter<WalletModel> {
  @override
  final int typeId = 3;

  @override
  WalletModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WalletModel(
      id: fields[0] as String,
      name: fields[1] as String,
      isDefault: fields[2] as bool,
      imagePath: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, WalletModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.isDefault)
      ..writeByte(3)
      ..write(obj.imagePath);
  }
}
