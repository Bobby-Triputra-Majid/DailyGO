import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/category_model.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_period.dart';
import '../utils/grouping.dart';
import '../utils/icon_catalog.dart';

class TransactionTile extends StatelessWidget {
  final DisplayEntry entry;
  final CategoryModel? Function(String id) categoryResolver;
  final VoidCallback? onTap;

  /// Shows the delete confirmation and performs the delete, resolving to
  /// whether it actually happened — used both by the revealed "Hapus"
  /// button and, if the swipe is carried all the way through, by
  /// [DismissiblePane] (which only plays the dismiss animation when this
  /// resolves true).
  final Future<bool> Function()? onDelete;

  /// Optional extra info row shown under the subtitle — e.g. the Grab
  /// tab's tip / top-up badges on a trip entry. Every other caller leaves
  /// this null and the tile looks exactly as before.
  final Widget? extra;

  /// Optional small badge shown inline next to the title — e.g. the Grab
  /// tab's Tunai/Non-Tunai pill — so it doesn't add extra height to the
  /// tile the way [extra] does.
  final Widget? titleBadge;

  /// Optional small note shown under the amount — e.g. "Tip Rp700" or
  /// "Kurang Rp200" on a Grab trip — without adding extra height to the
  /// tile the way [extra] does.
  final String? trailingNote;

  /// Optional icon shown before [trailingNote].
  final IconData? trailingNoteIcon;

  /// Optional color for [trailingNoteIcon] — e.g. red for a shortage,
  /// blue for a tip. Defaults to a muted grey when not given.
  final Color? trailingNoteColor;

  const TransactionTile({
    super.key,
    required this.entry,
    required this.categoryResolver,
    this.onTap,
    this.onDelete,
    this.extra,
    this.titleBadge,
    this.trailingNote,
    this.trailingNoteIcon,
    this.trailingNoteColor,
  });

  @override
  Widget build(BuildContext context) {
    final primaryCat = categoryResolver(entry.primary.categoryId);
    // A single transaction is income/expense exactly as tagged; a group
    // (e.g. a Grab trip's fare+tip alongside its admin-fee expense) goes
    // by the net sign instead, since it can legitimately mix both types.
    final isIncome = entry.isGroup ? entry.totalAmount >= 0 : entry.primary.type == TxType.income;
    final color = primaryCat != null ? Color(primaryCat.colorValue) : Colors.grey;
    final icon = primaryCat != null ? iconFromCodePoint(primaryCat.iconCodePoint) : Icons.category;

    // groupLabel wins whenever this row actually has a groupId — including
    // a single-transaction "group" (e.g. a Grab trip that's just a fare
    // with no tip/top-up/admin-fee legs), which used to fall back to the
    // category name ("Grab") instead of "Trip Grab", reading as a
    // different, inconsistent kind of row. A standalone BBM/Makan entry
    // also carries groupLabel 'Trip Grab' (just for filtering elsewhere)
    // but has no groupId, so it's unaffected and still shows its own
    // category name.
    final title = (entry.groupId != null ? entry.groupLabel : null) ?? primaryCat?.name ?? 'Transaksi';

    // A grouped trip's fare+tip breakdown isn't shown here — the tip (or
    // shortage) badge next to the amount already covers that — so this
    // is just the note on its own line plus the date/time on a second,
    // smaller line below it — a note alone, with no date, made entries
    // like "Ke kampus" or a BBM fill-up impossible to place in time.
    final note = entry.primary.note;
    final dateLabel = formatDateTimeLabel(entry.date);

    final tile = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          dense: true,
          onTap: () => _showDetailSheet(context, title, icon, color, isIncome),
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Row(
            children: [
              Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ?titleBadge,
            ],
          ),
          subtitle: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (note != null && note.isNotEmpty)
                Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, height: 1.2)),
              Text(
                dateLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, height: 1.2, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          trailing: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIncome ? '+' : '-'}${formatRupiah(entry.totalAmount.abs())}',
                style: TextStyle(
                  color: isIncome ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (trailingNoteIcon != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(trailingNoteIcon, size: 13, color: trailingNoteColor ?? Theme.of(context).colorScheme.onSurfaceVariant),
                    if (trailingNote != null) ...[
                      const SizedBox(width: 3),
                      Text(
                        trailingNote!,
                        style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
        if (extra != null) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: extra!),
      ],
    );

    final actions = <Widget>[
      if (onTap != null)
        SlidableAction(
          onPressed: (_) => onTap!(),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          icon: Icons.edit,
          label: 'Edit',
        ),
      if (onDelete != null)
        SlidableAction(
          onPressed: (_) => onDelete!(),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          icon: Icons.delete,
          label: 'Hapus',
        ),
    ];

    if (actions.isEmpty) return tile;

    // First swipe reveals the action buttons (Edit/Hapus) and stops; only
    // carrying the swipe all the way through past that triggers an actual
    // delete, via the same confirmation dialog as tapping "Hapus" itself.
    return Slidable(
      key: ValueKey(entry.groupId ?? entry.primary.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: (0.25 * actions.length).clamp(0.25, 0.5),
        dismissible: onDelete == null
            ? null
            : DismissiblePane(
                confirmDismiss: () async => await onDelete!(),
                onDismissed: () {},
              ),
        children: actions,
      ),
      child: tile,
    );
  }

  /// A clean detail view for the tapped row — time, title, note, amount —
  /// shown instead of jumping straight into the edit form. Editing is now
  /// one deliberate extra tap away, via the button inside.
  void _showDetailSheet(BuildContext context, String title, IconData icon, Color color, bool isIncome) {
    final note = entry.primary.note;
    final time = '${entry.date.hour.toString().padLeft(2, '0')}:${entry.date.minute.toString().padLeft(2, '0')}';
    final fullDate = '${formatLongDate(entry.date)} • $time';

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(radius: 24, backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          '${isIncome ? '+' : '-'}${formatRupiah(entry.totalAmount.abs())}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isIncome ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _detailRow(ctx, Icons.schedule_outlined, fullDate),
              if (note != null && note.isNotEmpty) ...[
                const SizedBox(height: 12),
                _detailRow(ctx, Icons.notes_outlined, note),
              ],
              if (trailingNote != null) ...[
                const SizedBox(height: 12),
                _detailRow(ctx, trailingNoteIcon ?? Icons.info_outline, trailingNote!),
              ],
              if (onTap != null) ...[
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      onTap!();
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    );
  }
}
