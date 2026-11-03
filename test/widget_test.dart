// Basic smoke test: the app should boot into the dashboard without crashing.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:manajemen_keuangan/app.dart';
import 'package:manajemen_keuangan/data/hive_boxes.dart';
import 'package:manajemen_keuangan/providers/finance_provider.dart';

void main() {
  testWidgets('App boots to dashboard', (WidgetTester tester) async {
    await HiveBoxes.init();

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => FinanceProvider(),
        child: const KeuanganApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('KeuanganKu'), findsOneWidget);
  });
}
