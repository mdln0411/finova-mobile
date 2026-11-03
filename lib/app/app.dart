import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'routes/app_router.dart';
import 'theme/app_theme.dart';

class FinovaApp extends StatefulWidget {
  const FinovaApp({super.key});
  @override
  State<FinovaApp> createState() => _FinovaAppState();
}

class _FinovaAppState extends State<FinovaApp> {
  late final GoRouter _router = createAppRouter();
  @override
  void dispose() {
    _router.dispose();
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
