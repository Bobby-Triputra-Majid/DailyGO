import 'package:flutter/material.dart';
import '../models/wallet_model.dart';

/// Dropdown for picking which dompet a piece of money moves through —
/// shared by debt creation (piutang/utang) and debt settlement (Tandai
/// Lunas/Bayar Sebagian), so every picker in the app looks and behaves
/// the same.
class WalletDropdown extends StatelessWidget {
  final List<WalletModel> wallets;
  final String value;
  final ValueChanged<String> onChanged;
  final String label;

  const WalletDropdown({
    super.key,
    required this.wallets,
    required this.value,
    required this.onChanged,
    this.label = 'Dompet',
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: wallets.any((w) => w.id == value) ? value : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      items: wallets.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
