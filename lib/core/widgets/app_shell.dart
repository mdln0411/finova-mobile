import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final index = switch (location) {
      '/' => 0,
      '/transactions' => 1,
      '/approvals' => 2,
      _ => 3,
    };
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: child,
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (index) =>
              context.go(['/', '/transactions', '/approvals', '/menu'][index]),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(
                Icons.space_dashboard_rounded,
                color: AppColors.primary,
              ),
              label: 'Beranda',
            ),
            NavigationDestination(
              icon: Icon(Icons.swap_horiz_rounded),
              label: 'Transaksi',
            ),
            NavigationDestination(
              icon: Icon(Icons.fact_check_outlined),
              label: 'Persetujuan',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_rounded),
              label: 'Menu',
            ),
          ],
        ),
      ),
    );
  }
}
