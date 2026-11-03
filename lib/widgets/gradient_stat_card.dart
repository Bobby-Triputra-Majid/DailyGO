import 'package:flutter/material.dart';
import '../utils/currency_formatter.dart';

/// Solid badge color for an income-side [StatItemData] (e.g. Ongkos,
/// Tip, Pemasukan).
const Color kStatIncomeColor = Color(0xFF43A047);

/// Solid badge color for an expense-side [StatItemData] (e.g. BBM,
/// Pengeluaran).
const Color kStatExpenseColor = Color(0xFFE53935);

/// One figure inside a [GradientStatCard]'s bottom row (e.g. "Pemasukan",
/// "Ongkos").
class StatItemData {
  final IconData icon;
  final String label;
  final double value;

  /// Solid fill for the icon's badge circle (e.g. green for income, red
  /// for expense). The value text always stays white for guaranteed
  /// contrast against the card; only the small icon badge carries the
  /// color. Defaults to a neutral translucent white when not given.
  final Color? color;

  const StatItemData({required this.icon, required this.label, required this.value, this.color});
}

/// Shared gradient summary card used by both Beranda and the Grab tab.
/// Keeping it as one widget (fixed padding, font sizes, row heights)
/// guarantees both screens render the same height, so switching tabs
/// never causes a visible jump/flicker from mismatched card sizes.
///
/// [subtitle] is always rendered (as a blank line when null) so the card
/// is the same height whether or not a screen has a subtitle to show.
class GradientStatCard extends StatelessWidget {
  final String title;
  final double mainValue;
  final String? subtitle;
  final List<StatItemData> stats;

  /// [mainValue] from the previous period of the same length (e.g.
  /// yesterday when viewing "Hari ini"). When given and different from
  /// [mainValue], a small trending-up/down badge is shown next to the
  /// main figure comparing the two.
  final double? previousValue;

  /// Whether an eye icon is shown next to the title, and its current
  /// state (open = on). Null hides the icon entirely — most cards don't
  /// need it. Used e.g. on the Grab tab to toggle whether a lump BBM
  /// purchase (which doesn't run out in a single day) is subtracted from
  /// that day's Pendapatan Bersih, since otherwise the one day it's
  /// bought looks misleadingly low.
  final bool? toggleOn;
  final VoidCallback? onToggle;
  final String? toggleTooltip;

  const GradientStatCard({
    super.key,
    required this.title,
    required this.mainValue,
    required this.stats,
    this.subtitle,
    this.previousValue,
    this.toggleOn,
    this.onToggle,
    this.toggleTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showTrend = previousValue != null && previousValue != mainValue;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
              ),
              if (onToggle != null)
                Tooltip(
                  message: toggleTooltip ?? '',
                  child: InkWell(
                    onTap: onToggle,
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        (toggleOn ?? true) ? Icons.visibility : Icons.visibility_outlined,
                        size: 18,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                formatRupiah(mainValue),
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              if (showTrend) ...[
                const SizedBox(width: 8),
                _TrendBadge(current: mainValue, previous: previousValue!),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle ?? '',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(children: _buildStatRow()),
        ],
      ),
    );
  }

  List<Widget> _buildStatRow() {
    final widgets = <Widget>[];
    for (var i = 0; i < stats.length; i++) {
      widgets.add(Expanded(child: _StatItem(data: stats[i])));
      if (i != stats.length - 1) {
        widgets.add(Container(width: 1, height: 36, color: Colors.white24));
      }
    }
    return widgets;
  }
}

/// "Stonk"-style indicator comparing [current] to [previous] — just a
/// plain green trending-up arrow when it rose, red trending-down when
/// it fell, no badge background.
class _TrendBadge extends StatelessWidget {
  final double current;
  final double previous;

  const _TrendBadge({required this.current, required this.previous});

  @override
  Widget build(BuildContext context) {
    final isUp = current > previous;
    final color = isUp ? kStatIncomeColor : kStatExpenseColor;
    return Icon(isUp ? Icons.trending_up : Icons.trending_down, size: 22, color: color);
  }
}

class _StatItem extends StatelessWidget {
  final StatItemData data;

  const _StatItem({required this.data});

  @override
  Widget build(BuildContext context) {
    final hasColor = data.color != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: hasColor ? data.color : Colors.white.withOpacity(0.15),
            child: Icon(data.icon, size: 12, color: Colors.white),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatRupiah(data.value, withSymbol: false),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
