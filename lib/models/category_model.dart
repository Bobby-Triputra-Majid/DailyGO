import 'package:hive/hive.dart';

enum TxType { income, expense }

class CategoryModel extends HiveObject {
  String id;
  String name;
  TxType type;
  int colorValue;
  int iconCodePoint;
  bool isDefault;

  CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    required this.colorValue,
    required this.iconCodePoint,
    this.isDefault = false,
  });
}

class CategoryModelAdapter extends TypeAdapter<CategoryModel> {
  @override
  final int typeId = 0;

  @override
  CategoryModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CategoryModel(
      id: fields[0] as String,
      name: fields[1] as String,
      type: TxType.values[fields[2] as int],
      colorValue: fields[3] as int,
      iconCodePoint: fields[4] as int,
      isDefault: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, CategoryModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type.index)
      ..writeByte(3)
      ..write(obj.colorValue)
      ..writeByte(4)
      ..write(obj.iconCodePoint)
      ..writeByte(5)
      ..write(obj.isDefault);
  }
}
