import 'package:flutter/material.dart';
import '../utils/date_period.dart';

class PeriodSelector extends StatelessWidget {
  final PeriodType type;
  final PeriodRange range;
  final ValueChanged<PeriodType> onTypeChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback? onToday;

  const PeriodSelector({
    super.key,
    required this.type,
    required this.range,
    required this.onTypeChanged,
    required this.onPrev,
    required this.onNext,
    this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: PeriodType.values.map((t) {
              final selected = t == type;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(_label(t)),
                  selected: selected,
                  onSelected: (_) => onTypeChanged(t),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: onToday,
                  child: Text(
                    range.label,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
          ],
        ),
      ],
    );
  }

  String _label(PeriodType t) {
    switch (t) {
      case PeriodType.day:
        return 'Harian';
      case PeriodType.week:
        return 'Minggu';
      case PeriodType.month:
        return 'Bulan';
      case PeriodType.year:
        return 'Tahun';
    }
  }
}
