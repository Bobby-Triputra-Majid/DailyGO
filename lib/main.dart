import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'data/hive_boxes.dart';
import 'providers/asset_provider.dart';
import 'providers/finance_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/wallet_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveBoxes.init();
  final themeProvider = ThemeProvider();
  await themeProvider.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FinanceProvider()),
        ChangeNotifierProvider(create: (_) => AssetProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: const KeuanganApp(),
    ),
  );
}
