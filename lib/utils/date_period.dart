/// The current moment in WIB (UTC+7) — this app is only used in Indonesia,
/// so "now" always means WIB wall-clock time, regardless of what timezone
/// the device itself is set to.
DateTime nowWib() {
  final wib = DateTime.now().toUtc().add(const Duration(hours: 7));
  return DateTime(wib.year, wib.month, wib.day, wib.hour, wib.minute, wib.second, wib.millisecond, wib.microsecond);
}

const List<String> shortMonths = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des',
];

const List<String> longMonths = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

const List<String> dayNames = [
  'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
];

String formatShortDate(DateTime d) => '${d.day} ${shortMonths[d.month - 1]} ${d.year}';

/// Full date with day name, e.g. "Senin, 1 November 2026" — used as the
/// Beranda header subtitle.
String formatLongDate(DateTime d) => '${dayNames[d.weekday - 1]}, ${d.day} ${longMonths[d.month - 1]} ${d.year}';

/// A relative day label plus the time, e.g. "Hari ini, 14:05" or
/// "23 Okt 2026, 09:10" — used as a transaction's subtitle when it has no
/// note, so the day is always clear even in lists that span many days
/// (like Beranda's "Transaksi Terbaru", which isn't grouped by date).
String formatDateTimeLabel(DateTime d) {
  final now = nowWib();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final time = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  if (day == today) return 'Hari ini, $time';
  if (day == today.subtract(const Duration(days: 1))) return 'Kemarin, $time';
  return '${formatShortDate(d)}, $time';
}

enum PeriodType { day, week, month, year }

class PeriodRange {
  final DateTime start; // inclusive
  final DateTime end; // exclusive
  final String label;

  const PeriodRange(this.start, this.end, this.label);

  bool contains(DateTime date) => !date.isBefore(start) && date.isBefore(end);
}

class PeriodUtils {
  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static PeriodRange rangeFor(PeriodType type, DateTime anchor) {
    switch (type) {
      case PeriodType.day:
        final start = _startOfDay(anchor);
        final end = start.add(const Duration(days: 1));
        return PeriodRange(start, end, _formatDay(start));
      case PeriodType.week:
        final start = _startOfDay(anchor).subtract(Duration(days: anchor.weekday - 1));
        final end = start.add(const Duration(days: 7));
        return PeriodRange(start, end, _formatWeek(start, end));
      case PeriodType.month:
        final start = DateTime(anchor.year, anchor.month, 1);
        final end = DateTime(anchor.year, anchor.month + 1, 1);
        return PeriodRange(start, end, '${longMonths[start.month - 1]} ${start.year}');
      case PeriodType.year:
        final start = DateTime(anchor.year, 1, 1);
        final end = DateTime(anchor.year + 1, 1, 1);
        return PeriodRange(start, end, '${anchor.year}');
    }
  }

  static DateTime shift(PeriodType type, DateTime anchor, int direction) {
    switch (type) {
      case PeriodType.day:
        return anchor.add(Duration(days: direction));
      case PeriodType.week:
        return anchor.add(Duration(days: 7 * direction));
      case PeriodType.month:
        return DateTime(anchor.year, anchor.month + direction, 1);
      case PeriodType.year:
        return DateTime(anchor.year + direction, 1, 1);
    }
  }

  static String _formatDay(DateTime d) {
    final now = nowWib();
    final today = _startOfDay(now);
    if (d == today) return 'Hari ini';
    if (d == today.subtract(const Duration(days: 1))) return 'Kemarin';
    return '${dayNames[d.weekday - 1]}, ${formatShortDate(d)}';
  }

  static String _formatWeek(DateTime start, DateTime end) {
    final lastDay = end.subtract(const Duration(days: 1));
    if (start.month == lastDay.month) {
      return '${start.day} - ${lastDay.day} ${shortMonths[start.month - 1]} ${start.year}';
    }
    return '${start.day} ${shortMonths[start.month - 1]} - ${lastDay.day} ${shortMonths[lastDay.month - 1]} ${lastDay.year}';
  }
}
