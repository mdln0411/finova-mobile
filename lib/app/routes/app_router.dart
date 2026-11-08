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
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/auth_page.dart';
import '../../features/auth/presentation/session_page.dart';
import '../../features/auth/presentation/complete_profile_page.dart';
import '../../features/company/application/company_controller.dart';
import '../../features/company/domain/company.dart';
import '../../features/company/presentation/company_onboarding_page.dart';
import '../../features/company/presentation/company_form_page.dart';
import '../../features/company/presentation/company_invitations_page.dart';
import '../../features/chart_of_accounts/domain/chart_of_accounts_repository.dart';
import '../../features/chart_of_accounts/data/firebase_chart_of_accounts_repository.dart';
import '../../features/chart_of_accounts/presentation/chart_of_accounts_page.dart';
import '../../features/transactions/domain/transactions_repository.dart';
import '../../features/transactions/data/firebase_transactions_repository.dart';

GoRouter createAppRouter({
  required AuthController auth,
  required CompanyController company,
  ChartOfAccountsRepository? chartRepository,
  TransactionsRepository? transactionsRepository,
  String initialLocation = '/',
}) {
  final coaRepository = chartRepository ?? FirebaseChartOfAccountsRepository();
  final txRepository =
      transactionsRepository ?? FirebaseTransactionsRepository();
  Widget companyScoped(Widget Function(CompanyContext current) builder) =>
      ListenableBuilder(
        listenable: company,
        builder: (context, _) {
          final current = company.context;
          if (current == null) return const SizedBox.shrink();
          return builder(current);
        },
      );
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: Listenable.merge([auth, company]),
    redirect: (context, state) {
      final path = state.uri.path;
      final isAuthPage = [
        '/login',
        '/register',
        '/forgot-password',
      ].contains(path);
      final authRedirect = switch (auth.phase) {
        AuthPhase.loading ||
        AuthPhase.profileError ||
        AuthPhase.sessionError => path == '/session' ? null : '/session',
        AuthPhase.signedOut => isAuthPage ? null : '/login',
        AuthPhase.profileIncomplete =>
          path == '/complete-profile' ? null : '/complete-profile',
        AuthPhase.signedIn => null,
      };
      if (auth.phase != AuthPhase.signedIn) return authRedirect;
      switch (company.phase) {
        case CompanyPhase.waiting:
        case CompanyPhase.loading:
        case CompanyPhase.error:
          return path == '/company' ? null : '/company';
        case CompanyPhase.noCompany:
          return ['/company', '/company/create', '/company/join'].contains(path)
              ? null
              : '/company';
        case CompanyPhase.active:
          if (path == '/company/invitations' &&
              company.context?.role != CompanyRole.manager) {
            return '/';
          }
          return isAuthPage ||
                  path == '/session' ||
                  path == '/complete-profile' ||
                  [
                    '/company',
                    '/company/create',
                    '/company/join',
                  ].contains(path)
              ? '/'
              : null;
      }
    },
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
      GoRoute(
        path: '/company',
        builder: (context, state) => CompanyOnboardingPage(controller: company),
      ),
      GoRoute(
        path: '/company/create',
        builder: (context, state) => CompanyFormPage(controller: company),
      ),
      GoRoute(
        path: '/company/join',
        builder: (context, state) =>
            CompanyInvitationsPage(controller: company),
      ),
      GoRoute(
        path: '/company/invitations',
        builder: (context, state) =>
            CompanyInvitationsPage(controller: company, manage: true),
      ),
      GoRoute(
        path: '/complete-profile',
        builder: (context, state) => CompleteProfilePage(controller: auth),
      ),
      GoRoute(
        path: '/session',
        builder: (context, state) => SessionPage(controller: auth),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => AuthPage(
          key: const ValueKey('login'),
          controller: auth,
          mode: AuthPageMode.login,
        ),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => AuthPage(
          key: const ValueKey('register'),
          controller: auth,
          mode: AuthPageMode.register,
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => AuthPage(
          key: const ValueKey('reset'),
          controller: auth,
          mode: AuthPageMode.reset,
        ),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => ListenableBuilder(
              listenable: Listenable.merge([auth, company]),
              builder: (context, _) {
                final current = company.context;
                if (current == null) return const SizedBox.shrink();
                return DashboardPage(
                  userName: auth.profile?.displayName,
                  company: current,
                );
              },
            ),
          ),
          GoRoute(
            path: '/transactions',
            builder: (context, state) => companyScoped(
              (current) => TransactionsPage(
                key: ValueKey('tx:${current.company.id}:${current.role.name}'),
                company: current,
                userId: auth.user?.uid,
                repository: txRepository,
                chartRepository: coaRepository,
              ),
            ),
          ),
          GoRoute(
            path: '/approvals',
            builder: (context, state) => companyScoped(
              (current) => ApprovalsPage(
                key: ValueKey('ap:${current.company.id}:${current.role.name}'),
                company: current,
                userId: auth.user?.uid,
                repository: txRepository,
                chartRepository: coaRepository,
              ),
            ),
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
            path: '/categories',
            builder: (context, state) => ListenableBuilder(
              listenable: company,
              builder: (context, _) {
                final current = company.context;
                if (current == null) return const SizedBox.shrink();
                return ChartOfAccountsPage(
                  key: ValueKey('${current.company.id}:${current.role.name}'),
                  company: current,
                  repository: coaRepository,
                );
              },
            ),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => ListenableBuilder(
              listenable: company,
              builder: (context, _) {
                final current = company.context;
                if (current == null) return const SizedBox.shrink();
                return SettingsPage(
                  auth: auth,
                  company: current,
                  companyController: company,
                );
              },
            ),
          ),
        ],
      ),
    ],
  );
}
