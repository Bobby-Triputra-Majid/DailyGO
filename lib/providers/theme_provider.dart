import 'package:flutter/material.dart';
import '../data/hive_boxes.dart';

/// Persists the user's light/dark preference in the shared settings
/// Hive box ([HiveBoxes.settings]) — a plain dynamic box is enough here
/// since we're only storing a bool, no custom TypeAdapter needed.
class ThemeProvider extends ChangeNotifier {
  static const String _key = 'isDarkMode';

  bool _isDark = false;

  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  Future<void> init() async {
    _isDark = HiveBoxes.settings.get(_key, defaultValue: false) as bool;
  }

  void toggle() {
    _isDark = !_isDark;
    HiveBoxes.settings.put(_key, _isDark);
    notifyListeners();
  }
}
