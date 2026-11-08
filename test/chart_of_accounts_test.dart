import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finova/app/routes/app_router.dart';
import 'package:finova/app/theme/app_theme.dart';
import 'package:finova/features/chart_of_accounts/application/chart_of_accounts_controller.dart';
import 'package:finova/features/chart_of_accounts/data/chart_account_codec.dart';
import 'package:finova/features/chart_of_accounts/domain/chart_account.dart';
import 'package:finova/features/chart_of_accounts/domain/default_chart_of_accounts.dart';
import 'package:finova/features/chart_of_accounts/presentation/chart_of_accounts_page.dart';
import 'package:finova/features/company/domain/company.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_repository.dart';
import 'support/fake_chart_of_accounts_repository.dart';
import 'support/fake_company_repository.dart';

void main() {
  test(
    'Default chart lengkap lima tipe, kode unik dan saldo normal konsisten',
    () {
      ChartAccount.validateChart(defaultChartOfAccounts);
      expect(defaultChartOfAccounts.length, 23);
      expect(
        defaultChartOfAccounts.map((account) => account.code).toSet().length,
        23,
      );
      expect(
        defaultChartOfAccounts.where((account) => !account.isPosting).length,
        5,
      );
      for (final type in AccountType.values) {
        final accounts = defaultChartOfAccounts.where(
          (account) => account.type == type,
        );
        expect(accounts.where((account) => account.isPosting), isNotEmpty);
        expect(
          accounts.every(
            (account) => account.normalBalance == type.normalBalance,
          ),
          isTrue,
        );
      }
      expect(
        defaultChartOfAccounts
            .firstWhere((account) => account.code == '1400')
            .type,
        AccountType.asset,
      );
      expect(
        defaultChartOfAccounts
            .firstWhere((account) => account.code == '2200')
            .type,
        AccountType.liability,
      );
      expect(
        defaultChartOfAccounts
            .firstWhere((account) => account.code == '3100')
            .type,
        AccountType.equity,
      );
    },
  );

  test('Validasi menolak kode/nama/saldo normal/induk dan posting kelompok yang salah', () {
    ChartAccount account({
      String code = '4100',
      String name = 'Penjualan',
      BalanceSide side = BalanceSide.credit,
      String? parent = '4000',
      bool posting = true,
    }) => ChartAccount(
      code: code,
      name: name,
      type: AccountType.revenue,
      normalBalance: side,
      parentCode: parent,
      isPosting: posting,
    );
    expect(account().validate(), isNull);
    for (final invalid in [
      account(code: '5100'),
      account(code: '../x'),
      account(name: ' '),
      account(name: ' A '),
      account(name: 'A\nB'),
      account(name: 'A' * 101),
      account(side: BalanceSide.debit),
      account(parent: '5000'),
      account(code: '4000'),
    ]) {
      expect(invalid.validate(), isNotNull);
    }
    expect(
      () => ChartAccount.validateChart([account()]),
      throwsA(isA<ChartOfAccountsFailure>()),
    );
    expect(
      () => ChartAccount.validateChart([
        ...defaultChartOfAccounts,
        defaultChartOfAccounts.first,
      ]),
      throwsA(isA<ChartOfAccountsFailure>()),
    );
  });

  test('Codec membaca tipe/metadata valid dan gagal tertutup pada data Firestore rusak', () {
    final account = defaultChartOfAccounts.first;
    final timestamp = Timestamp.fromDate(DateTime.utc(2026));
    final data = {
      ...ChartAccountCodec.values(account),
      'createdBy': 'owner',
      'createdAt': timestamp,
      'updatedAt': timestamp,
    };
    expect(
      ChartAccountCodec.fromDocument(account.code, data).code,
      account.code,
    );
    for (final changes in [
      {'code': 'other'},
      {'type': 'unknown'},
      {'normalBalance': 'wrong'},
      {'isPosting': 'false'},
      {'parentCode': 1000},
      {'createdAt': null},
      {'createdBy': ''},
      {'updatedAt': Timestamp.fromDate(DateTime.utc(2025))},
    ]) {
      expect(
        () =>
            ChartAccountCodec.fromDocument(account.code, {...data, ...changes}),
        throwsA(isA<ChartOfAccountsFailure>()),
      );
    }
  });

  test(
    'Controller mencegah double submit, melakukan retry aman dan filter',
    () async {
      final repo = FakeChartOfAccountsRepository();
      final controller = ChartOfAccountsController(
        repo,
        companyId: 'company-1',
        canInitialize: true,
      );
      addTearDown(() async {
        controller.dispose();
        await repo.dispose();
      });
      await flushAuth();
      repo.writeDelay = Completer<void>();
      final first = controller.initializeDefaults();
      expect(await controller.initializeDefaults(), isFalse);
      controller.retry();
      expect(repo.initializeCalls, 1);
      repo.writeDelay!.complete();
      expect(await first, isTrue);
      await flushAuth();
      expect(controller.accounts.length, 23);
      controller.setFilter(AccountType.revenue);
      expect(controller.visibleAccounts.length, 4);
      expect(
        controller.visibleAccounts.every(
          (account) => account.type == AccountType.revenue,
        ),
        isTrue,
      );
      expect(await controller.initializeDefaults(), isTrue);
      expect(controller.accounts.length, 23);
      expect(controller.notice, contains('sudah tersedia'));
      expect(repo.requestedCompany, 'company-1');
    },
  );

  test(
    'Finance tidak menginisialisasi dan save gagal dapat dicoba ulang',
    () async {
      final repo = FakeChartOfAccountsRepository();
      final finance = ChartOfAccountsController(
        repo,
        companyId: 'company-1',
        canInitialize: false,
      );
      addTearDown(finance.dispose);
      await flushAuth();
      expect(await finance.initializeDefaults(), isFalse);
      expect(repo.initializeCalls, 0);
      final manager = ChartOfAccountsController(
        repo,
        companyId: 'company-1',
        canInitialize: true,
      );
      addTearDown(() async {
        manager.dispose();
        await repo.dispose();
      });
      await flushAuth();
      repo.writeFailure = const ChartOfAccountsFailure('Jaringan terputus.');
      expect(await manager.initializeDefaults(), isFalse);
      expect(manager.accounts, isEmpty);
      expect(manager.actionError, 'Jaringan terputus.');
      expect(manager.busy, isFalse);
      repo.writeFailure = null;
      expect(await manager.initializeDefaults(), isTrue);
    },
  );

  testWidgets(
    'Manager melihat empty state, menyiapkan default dan memfilter pendapatan',
    (tester) async {
      final repo = FakeChartOfAccountsRepository();
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ChartOfAccountsPage(company: testCompany, repository: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Belum ada kategori akun.'), findsOneWidget);
      expect(repo.initializeCalls, 0);
      final button = find.text('Siapkan kategori default');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(repo.initializeCalls, 1);
      final filter = find.widgetWithText(ChoiceChip, 'Pendapatan');
      await tester.ensureVisible(filter);
      await tester.tap(filter);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Penjualan barang'), 200);
      expect(find.text('Penjualan barang'), findsOneWidget);
      expect(find.text('Beban gaji'), findsNothing);
    },
  );

  testWidgets(
    'Finance hanya membaca; tidak ada seed otomatis atau tombol Manager',
    (tester) async {
      final repo = FakeChartOfAccountsRepository();
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChartOfAccountsPage(
              company: CompanyContext(
                company: testCompany.company,
                role: CompanyRole.finance,
              ),
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Minta Manager'), findsOneWidget);
      expect(find.text('Siapkan kategori default'), findsNothing);
      expect(repo.initializeCalls, 0);
    },
  );

  testWidgets(
    'Error baca dapat dipulihkan; kategori dikunci kembali setelah logout',
    (tester) async {
      final auth = await readyAuth();
      final repo = FakeChartOfAccountsRepository()
        ..readFailure = const ChartOfAccountsFailure('Izin kategori ditolak.');
      addTearDown(repo.dispose);
      final router = createAppRouter(
        auth: auth,
        company: await readyCompany(auth),
        chartRepository: repo,
        initialLocation: '/categories',
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );
      await tester.pumpAndSettle();
      expect(find.text('Izin kategori ditolak.'), findsOneWidget);
      repo.readFailure = null;
      await tester.ensureVisible(find.text('Coba lagi'));
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Belum ada kategori akun.'), findsOneWidget);
      await auth.signOut();
      await tester.pumpAndSettle();
      expect(find.text('Kategori Akun'), findsNothing);
      expect(find.text('Selamat datang kembali.'), findsOneWidget);
    },
  );

  testWidgets(
    'Perubahan role server ke Finance melepas tombol inisialisasi Manager',
    (tester) async {
      final auth = await readyAuth();
      final companyRepo = FakeCompanyRepository();
      final company = await readyCompany(auth, repository: companyRepo);
      final repo = FakeChartOfAccountsRepository();
      addTearDown(repo.dispose);
      final router = createAppRouter(
        auth: auth,
        company: company,
        chartRepository: repo,
        initialLocation: '/categories',
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );
      await tester.pumpAndSettle();
      expect(find.text('Siapkan kategori default'), findsOneWidget);
      companyRepo.events.add(
        CompanyContext(company: testCompany.company, role: CompanyRole.finance),
      );
      await tester.pumpAndSettle();
      expect(find.text('Siapkan kategori default'), findsNothing);
      expect(find.textContaining('Minta Manager'), findsOneWidget);
      expect(repo.initializeCalls, 0);
    },
  );

  testWidgets('Kategori layar 320dp dengan teks besar tidak overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 750);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repo = FakeChartOfAccountsRepository()
      ..accounts = defaultChartOfAccounts;
    addTearDown(repo.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ChartOfAccountsPage(company: testCompany, repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 10; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
