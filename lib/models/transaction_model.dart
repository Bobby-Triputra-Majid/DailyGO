import 'package:hive/hive.dart';
import 'category_model.dart';

class TransactionModel extends HiveObject {
  String id;
  TxType type;
  double amount;
  String categoryId;
  DateTime date;
  String? note;
  String? groupId;
  String? groupLabel;

  /// Only set on a Grab trip's fare transaction — whether it was paid in
  /// cash or not, so the trip history can show it. Null for every other
  /// transaction (and for trips recorded before this field existed).
  bool? isCash;

  /// Only set on a Grab trip's fare transaction — what was actually
  /// billed to/received from the passenger, before Grab's minimum-fare
  /// top-up. When this is less than [amount], the difference was covered
  /// by the system, not the passenger. Null for every other transaction.
  double? billedAmount;

  /// Only set on a Grab trip's fare transaction — what was actually
  /// handed over by the passenger (cash) or received directly (non-cash),
  /// before any minimum-fare top-up. Lets an edit reconstruct the exact
  /// original figures even when there was a cash shortage. Null for
  /// every other transaction.
  double? receivedAmount;

  /// Only set on a *cash* Grab trip's fare transaction, and only when
  /// Grab's system takes a cut that isn't reflected in the cash handed
  /// over by the passenger — e.g. billed 16.000, passenger hands over
  /// 17.000 cash, but the system only credits 14.000 as the actual fare
  /// payout. When set, this — not [billedAmount]/the minimum-fare
  /// top-up — is booked as the "Ongkos Grab" income; [receivedAmount] vs
  /// [billedAmount] still drives the Tip/shortage calculation unchanged,
  /// since that's about physical cash, not the system payout. Null when
  /// there's no separate system cut to account for.
  double? netPayoutAmount;

  /// Which dompet (Cash / Saldo Grab / Bank / ...) this transaction's
  /// money sits in or moved out of. Null on records saved before the
  /// dompet feature existed — treated as the default Cash wallet.
  String? walletId;

  /// True for one leg of a transfer between two dompets (e.g. "Tarik
  /// Saldo Grab") — never real income or expense, so every income/expense
  /// total, category breakdown, and trend chart skips these by default.
  /// A genuine cost tied to a transfer (e.g. the bank's admin fee) is its
  /// own ordinary transaction with this left false, so it still counts.
  bool isTransfer;

  /// Only set on a Grab trip's fare transaction — true when the trip was
  /// taken outside the Grab app (flagged down directly by a passenger),
  /// so none of the app-specific billing math (minimum fare top-up,
  /// system cut/potongan) applies — the amount booked is simply what was
  /// received. Null/false for an ordinary in-app trip.
  bool? isOffline;

  TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.date,
    this.note,
    this.groupId,
    this.groupLabel,
    this.isCash,
    this.billedAmount,
    this.receivedAmount,
    this.netPayoutAmount,
    this.walletId,
    this.isTransfer = false,
    this.isOffline,
  });
}

class TransactionModelAdapter extends TypeAdapter<TransactionModel> {
  @override
  final int typeId = 1;

  @override
  TransactionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TransactionModel(
      id: fields[0] as String,
      type: TxType.values[fields[1] as int],
      amount: fields[2] as double,
      categoryId: fields[3] as String,
      date: DateTime.fromMillisecondsSinceEpoch(fields[4] as int),
      note: fields[5] as String?,
      groupId: fields[6] as String?,
      groupLabel: fields[7] as String?,
      isCash: fields[8] as bool?,
      billedAmount: fields[9] as double?,
      receivedAmount: fields[10] as double?,
      netPayoutAmount: fields[11] as double?,
      walletId: fields[12] as String?,
      isTransfer: fields[13] as bool? ?? false,
      isOffline: fields[14] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, TransactionModel obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type.index)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.categoryId)
      ..writeByte(4)
      ..write(obj.date.millisecondsSinceEpoch)
      ..writeByte(5)
      ..write(obj.note)
      ..writeByte(6)
      ..write(obj.groupId)
      ..writeByte(7)
      ..write(obj.groupLabel)
      ..writeByte(8)
      ..write(obj.isCash)
      ..writeByte(9)
      ..write(obj.billedAmount)
      ..writeByte(10)
      ..write(obj.receivedAmount)
      ..writeByte(11)
      ..write(obj.netPayoutAmount)
      ..writeByte(12)
      ..write(obj.walletId)
      ..writeByte(13)
      ..write(obj.isTransfer)
      ..writeByte(14)
      ..write(obj.isOffline);
  }
}
