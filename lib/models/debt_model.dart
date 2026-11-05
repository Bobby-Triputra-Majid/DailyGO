import 'package:hive/hive.dart';

/// theyOweMe = piutang (orang berutang ke saya).
/// iOweThem = utang (saya berutang ke orang).
enum DebtDirection { theyOweMe, iOweThem }

class DebtModel extends HiveObject {
  String id;
  String personName;
  double amount;
  DebtDirection direction;
  DateTime date;
  String? note;
  bool isPaid;
  DateTime? paidDate;

  /// How much of [amount] has been paid back so far — lets a debt be
  /// settled in installments instead of all at once. 0 until the first
  /// payment; reaches [amount] exactly when [isPaid] flips to true.
  double paidAmount;

  /// Ids of every income/expense transaction booked for a payment toward
  /// this debt (one per installment, or a single one for a full
  /// payment) — so deleting this debt record can also remove them,
  /// instead of leaving orphaned entries in Riwayat Transaksi.
  List<String> settlementTransactionIds;

  /// Which dompet the money moved through the moment this record was
  /// created — taken from (piutang: lending cash out) or received into
  /// (utang: borrowing cash in). Null only for a record saved before this
  /// field existed, which has no wallet transaction tied to it yet.
  String? walletId;

  /// Id of the wallet transaction (tagged [TransactionModel.isTransfer])
  /// that moved [amount] through [walletId] when this debt was created —
  /// kept in sync whenever the amount/direction/wallet is edited, and
  /// removed along with the debt. Null for a legacy debt that predates
  /// wallet tracking.
  String? originTransactionId;

  /// How much is still owed. Clamped so a rounding slip can't leave a
  /// "paid off" debt showing a tiny leftover balance.
  double get remaining => (amount - paidAmount).clamp(0.0, amount);

  DebtModel({
    required this.id,
    required this.personName,
    required this.amount,
    required this.direction,
    required this.date,
    this.note,
    this.isPaid = false,
    this.paidDate,
    this.paidAmount = 0.0,
    List<String>? settlementTransactionIds,
    this.walletId,
    this.originTransactionId,
  }) : settlementTransactionIds = settlementTransactionIds ?? [];
}

class DebtModelAdapter extends TypeAdapter<DebtModel> {
  @override
  final int typeId = 2;

  @override
  DebtModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DebtModel(
      id: fields[0] as String,
      personName: fields[1] as String,
      amount: fields[2] as double,
      direction: DebtDirection.values[fields[3] as int],
      date: DateTime.fromMillisecondsSinceEpoch(fields[4] as int),
      note: fields[5] as String?,
      isPaid: fields[6] as bool,
      paidDate: fields[7] == null ? null : DateTime.fromMillisecondsSinceEpoch(fields[7] as int),
      paidAmount: fields[8] as double? ?? 0.0,
      settlementTransactionIds: (fields[9] as List?)?.map((e) => e as String).toList() ?? [],
      walletId: fields[10] as String?,
      originTransactionId: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, DebtModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.personName)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.direction.index)
      ..writeByte(4)
      ..write(obj.date.millisecondsSinceEpoch)
      ..writeByte(5)
      ..write(obj.note)
      ..writeByte(6)
      ..write(obj.isPaid)
      ..writeByte(7)
      ..write(obj.paidDate?.millisecondsSinceEpoch)
      ..writeByte(8)
      ..write(obj.paidAmount)
      ..writeByte(9)
      ..write(obj.settlementTransactionIds)
      ..writeByte(10)
      ..write(obj.walletId)
      ..writeByte(11)
      ..write(obj.originTransactionId);
  }
}
