import 'package:flutter/material.dart';
import '../models/debt_model.dart';
import '../providers/asset_provider.dart';
import '../providers/finance_provider.dart';
import '../screens/debt_entry_screen.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_period.dart';
import '../widgets/amount_field.dart';

/// One row for a single debt record (used in the per-person detail list).
class DebtTile extends StatelessWidget {
  final DebtModel debt;
  final VoidCallback onTap;

  const DebtTile({super.key, required this.debt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isReceivable = debt.direction == DebtDirection.theyOweMe;
    final color = isReceivable ? Colors.green.shade700 : Colors.red.shade700;
    final hasPartialPayment = debt.paidAmount > 0 && !debt.isPaid;

    String subtitle;
    if (debt.isPaid) {
      subtitle = '${formatShortDate(debt.date)} • Lunas';
    } else if (hasPartialPayment) {
      subtitle = 'Sudah dibayar ${formatRupiah(debt.paidAmount)} dari ${formatRupiah(debt.amount)}';
    } else {
      subtitle = formatShortDate(debt.date);
    }

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.15),
        child: Icon(isReceivable ? Icons.call_received : Icons.call_made, color: color, size: 20),
      ),
      title: Text(debt.note != null && debt.note!.isNotEmpty ? debt.note! : 'Catatan'),
      subtitle: Text(
        subtitle,
        style: debt.isPaid ? TextStyle(color: colorScheme.onSurfaceVariant) : null,
      ),
      trailing: Text(
        formatRupiah(debt.isPaid ? debt.amount : debt.remaining),
        style: TextStyle(
          color: debt.isPaid ? colorScheme.onSurfaceVariant : color,
          fontWeight: FontWeight.bold,
          decoration: debt.isPaid ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}

/// Bottom sheet with actions for one debt record: pay it off (fully or
/// in part), edit it, or delete it.
void showDebtActions(
  BuildContext context,
  AssetProvider assetProvider,
  FinanceProvider financeProvider,
  DebtModel debt,
) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(debt.personName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              debt.paidAmount > 0 && !debt.isPaid
                  ? 'Sisa ${formatRupiah(debt.remaining)} dari ${formatRupiah(debt.amount)}'
                  : formatRupiah(debt.amount),
            ),
          ),
          if (!debt.isPaid) ...[
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Tandai Lunas'),
              onTap: () {
                assetProvider.markDebtPaid(debt, financeProvider);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('Bayar Sebagian'),
              onTap: () {
                Navigator.pop(ctx);
                _showPartialPaymentDialog(context, assetProvider, financeProvider, debt);
              },
            ),
          ],
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit'),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => DebtEntryScreen(existing: debt)));
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Hapus', style: TextStyle(color: Colors.red)),
            onTap: () {
              assetProvider.deleteDebt(debt.id, financeProvider);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    ),
  );
}

/// Asks how much is being paid now (e.g. owed Rp100.000, pays Rp70.000) —
/// capped at what's still owed; paying the full remaining amount here
/// settles the debt exactly like "Tandai Lunas" would.
void _showPartialPaymentDialog(
  BuildContext context,
  AssetProvider assetProvider,
  FinanceProvider financeProvider,
  DebtModel debt,
) {
  final ctrl = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final entered = parseFormattedAmount(ctrl.text);
        final tooMuch = entered > debt.remaining;
        return AlertDialog(
          title: const Text('Bayar Sebagian'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sisa utang: ${formatRupiah(debt.remaining)}'),
              const SizedBox(height: 12),
              AmountField(
                controller: ctrl,
                label: 'Jumlah dibayar sekarang',
                autofocus: true,
                onChanged: (_) => setState(() {}),
              ),
              if (tooMuch)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Tidak boleh lebih dari sisa utang.',
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error, fontSize: 12),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: (entered <= 0 || tooMuch)
                  ? null
                  : () {
                      assetProvider.payDebt(debt, entered, financeProvider);
                      Navigator.pop(ctx);
                    },
              child: const Text('Bayar'),
            ),
          ],
        );
      },
    ),
  );
}
