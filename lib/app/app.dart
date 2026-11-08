import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/company/application/company_controller.dart';
import '../features/company/data/firebase_company_repository.dart';
import '../features/company/domain/company_repository.dart';
import '../features/chart_of_accounts/domain/chart_of_accounts_repository.dart';

import 'routes/app_router.dart';
import 'theme/app_theme.dart';

class FinovaApp extends StatefulWidget {
  const FinovaApp({
    super.key,
    required this.authController,
    this.companyRepository,
    this.chartRepository,
  });
  final AuthController authController;
  final CompanyRepository? companyRepository;
  final ChartOfAccountsRepository? chartRepository;
  @override
  State<FinovaApp> createState() => _FinovaAppState();
}

class _FinovaAppState extends State<FinovaApp> {
  late final CompanyController _company = CompanyController(
    widget.authController,
    widget.companyRepository ?? FirebaseCompanyRepository(),
  );
  late final GoRouter _router = createAppRouter(
    auth: widget.authController,
    company: _company,
    chartRepository: widget.chartRepository,
  );
  @override
  void dispose() {
    _router.dispose();
    _company.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Finova',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    routerConfig: _router,
  );
}
