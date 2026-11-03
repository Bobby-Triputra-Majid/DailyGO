import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.decimalPattern('id_ID');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }
    final number = int.parse(digitsOnly);
    final newText = _formatter.format(number);
    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

double parseFormattedAmount(String text) {
  final digitsOnly = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsOnly.isEmpty) return 0;
  return double.parse(digitsOnly);
}

class AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final FocusNode? focusNode;

  const AmountField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.onChanged,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: [ThousandsSeparatorInputFormatter()],
      onChanged: onChanged,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint ?? '0',
        prefixText: 'Rp ',
      ),
    );
  }
}
