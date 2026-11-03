import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'grab_tab_screen.dart';
import 'piutang_screen.dart';
import 'reports_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;
  late final PageController _pageController = PageController(initialPage: _index);

  final _screens = const [
    DashboardScreen(),
    GrabTabScreen(),
    PiutangScreen(),
    ReportsScreen(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _screens.length,
        itemBuilder: (context, index) => RepaintBoundary(child: _screens[index]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goTo,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Transaksi'),
          NavigationDestination(icon: Icon(Icons.local_taxi_outlined), selectedIcon: Icon(Icons.local_taxi), label: 'Grab'),
          NavigationDestination(icon: Icon(Icons.handshake_outlined), selectedIcon: Icon(Icons.handshake), label: 'Utang/Piutang'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Laporan'),
        ],
      ),
    );
  }
}
