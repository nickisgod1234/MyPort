import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/dashboard')) return 1;
    if (location.startsWith('/portfolio')) return 2;
    if (location.startsWith('/analysis')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0; // DCA — หน้าหลัก
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/dca');
      case 1:
        context.go('/dashboard');
      case 2:
        context.go('/portfolio');
      case 3:
        context.go('/analysis');
      case 4:
        context.go('/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex(context),
          onTap: (i) => _onTap(context, i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'หลัก',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.pie_chart_outline),
              activeIcon: Icon(Icons.pie_chart),
              label: 'Portfolio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.beach_access_outlined),
              activeIcon: Icon(Icons.beach_access),
              label: 'เกษียณ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
