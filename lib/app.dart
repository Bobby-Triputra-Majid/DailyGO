import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';

// Sampled from the DailyGO logo's circle so the app's whole Material 3
// palette (buttons, cards, the gradient stat cards, ...) is derived from
// the same blue as the brand mark instead of an unrelated color.
const _seed = Color(0xFF0E5EB3);

ThemeData _buildTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  final isDark = brightness == Brightness.dark;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: isDark ? const Color(0xFF101418) : const Color(0xFFF5F7FA),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      border: UnderlineInputBorder(borderSide: BorderSide(color: colorScheme.outlineVariant)),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorScheme.outlineVariant)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: colorScheme.primary, width: 2)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surfaceContainerLow,
      elevation: 8,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colorScheme.surface,
    ),
    dividerColor: colorScheme.outlineVariant,
  );
}

class KeuanganApp extends StatelessWidget {
  const KeuanganApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'DailyGO',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: const SplashScreen(),
    );
  }
}
