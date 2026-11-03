import 'package:intl/intl.dart';

final NumberFormat _plainFormat = NumberFormat.decimalPattern('id_ID');

String formatRupiah(num value, {bool withSymbol = true}) {
  final formatted = _plainFormat.format(value.round());
  return withSymbol ? 'Rp $formatted' : formatted;
}

/// Thousands-separated digits only, no "Rp" prefix. Used to prefill
/// editable amount fields.
String formatPlainThousands(num value) => _plainFormat.format(value.round());
