import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category_model.dart';
import '../providers/finance_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_period.dart';
import '../utils/icon_catalog.dart';
import '../widgets/period_selector.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  PeriodType _periodType = PeriodType.month;
  DateTime _anchor = nowWib();
  TxType _type = TxType.income;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final range = PeriodUtils.rangeFor(_periodType, _anchor);
    final breakdown = provider.categoryBreakdown(range, _type);
    final total = breakdown.values.fold(0.0, (a, b) => a + b);
    final colorScheme = Theme.of(context).colorScheme;
    final typeColor = _type == TxType.income ? Colors.green.shade600 : Colors.red.shade600;

    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          PeriodSelector(
            type: _periodType,
            range: range,
            onTypeChanged: (t) => setState(() => _periodType = t),
            onPrev: () => setState(() => _anchor = PeriodUtils.shift(_periodType, _anchor, -1)),
            onNext: () => setState(() => _anchor = PeriodUtils.shift(_periodType, _anchor, 1)),
            onToday: () => setState(() => _anchor = nowWib()),
          ),
          const SizedBox(height: 16),
          SegmentedButton<TxType>(
            segments: const [
              ButtonSegment(value: TxType.income, label: Text('Pemasukan')),
              ButtonSegment(value: TxType.expense, label: Text('Pengeluaran')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [typeColor, typeColor.withOpacity(0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  formatRupiah(total),
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  _type == TxType.income ? 'Total Pemasukan' : 'Total Pengeluaran',
                  style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (breakdown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('Belum ada data di waktu ini', style: TextStyle(color: colorScheme.onSurfaceVariant))),
            )
          else
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Column(
                  children: [
                    SizedBox(
                      height: 220,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 50,
                          sections: breakdown.entries.map((e) {
                            final pct = total == 0 ? 0.0 : e.value / total * 100;
                            return PieChartSectionData(
                              value: e.value,
                              color: Color(e.key.colorValue),
                              title: '${pct.toStringAsFixed(0)}%',
                              radius: 55,
                              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...breakdown.entries.map((e) {
                      final pct = total == 0 ? 0.0 : e.value / total * 100;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Color(e.key.colorValue).withOpacity(0.15),
                              child: Icon(iconFromCodePoint(e.key.iconCodePoint), size: 16, color: Color(e.key.colorValue)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(e.key.name)),
                            Text('${pct.toStringAsFixed(1)}%', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                            const SizedBox(width: 10),
                            Text(formatRupiah(e.value), style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
