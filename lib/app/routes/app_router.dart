import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/app_shell.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/menu/presentation/menu_page.dart';
import '../../features/transactions/presentation/transactions_page.dart';
import '../../features/approvals/presentation/approvals_page.dart';
import '../../features/receivables/presentation/receivables_page.dart';
import '../../features/payables/presentation/payables_page.dart';
import '../../features/accounts/presentation/accounts_page.dart';
import '../../features/reports/presentation/reports_page.dart';
import '../../features/settings/presentation/settings_page.dart';

GoRouter createAppRouter({String initialLocation = '/'}) => GoRouter(
  initialLocation: initialLocation,
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Halaman tidak ditemukan')),
    body: Center(
      child: FilledButton(
        onPressed: () => context.go('/'),
        child: const Text('Ke Beranda'),
      ),
    ),
  ),
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const DashboardPage()),
        GoRoute(
          path: '/transactions',
          builder: (context, state) => const TransactionsPage(),
        ),
        GoRoute(
          path: '/approvals',
          builder: (context, state) => const ApprovalsPage(),
        ),
        GoRoute(path: '/menu', builder: (context, state) => const MenuPage()),
        GoRoute(
          path: '/receivables',
          builder: (context, state) => const ReceivablesPage(),
        ),
        GoRoute(
          path: '/payables',
          builder: (context, state) => const PayablesPage(),
        ),
        GoRoute(
          path: '/accounts',
          builder: (context, state) => const AccountsPage(),
        ),
        GoRoute(
          path: '/reports',
          builder: (context, state) => const ReportsPage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    ),
  ],
);
