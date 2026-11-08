import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finova/app/theme/app_theme.dart';
import 'package:finova/features/approvals/presentation/approvals_page.dart';
import 'package:finova/features/chart_of_accounts/domain/default_chart_of_accounts.dart';
import 'package:finova/features/company/domain/company.dart';
import 'package:finova/features/transactions/application/transactions_controller.dart';
import 'package:finova/features/transactions/data/transaction_codec.dart';
import 'package:finova/features/transactions/domain/finance_transaction.dart';
import 'package:finova/features/transactions/presentation/transactions_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_chart_of_accounts_repository.dart';
import 'support/fake_company_repository.dart';
import 'support/fake_transactions_repository.dart';

TransactionDraft draft({
  TransactionType type = TransactionType.expense,
  int amount = 150000,
  DateTime? date,
  String description = 'Beli ATK',
  String cash = '1100',
  String category = '5900',
}) => TransactionDraft(
  type: type,
  amount: amount,
  date: date ?? DateTime.utc(2026, 3, 2),
  description: description,
  cashAccountId: cash,
  categoryAccountId: category,
);

String? check(TransactionDraft value) => value.validate(
  accounts: defaultChartOfAccounts,
  bookkeepingStartDate: DateTime.utc(2026, 1, 1),
  now: DateTime.utc(2026, 6, 1),
);

void main() {
  test('Validasi draft: nominal, tanggal, keterangan, akun kas & kategori', () {
    expect(check(draft()), isNull);
    expect(
      check(
        draft(type: TransactionType.income, category: '4100', cash: '1200'),
      ),
      isNull,
    );
    expect(check(draft(amount: 0)), contains('Nominal'));
    expect(check(draft(amount: -5)), contains('Nominal'));
    expect(check(draft(amount: 1000000000000000)), contains('terlalu besar'));
    expect(check(draft(date: DateTime.utc(2025, 12, 31))), contains('awal'));
    expect(
      check(draft(date: DateTime.utc(2026, 6, 2))),
      contains('masa depan'),
    );
    expect(check(draft(description: '   ')), contains('Keterangan'));
    expect(check(draft(description: 'a' * 201)), contains('maksimal'));
    expect(check(draft(cash: '1300')), contains('Kas/Bank'));
    expect(check(draft(cash: '1000')), contains('Kas/Bank'));
    expect(check(draft(category: '4100')), contains('Beban'));
    expect(check(draft(category: '5000')), contains('Beban'));
    expect(
      check(draft(type: TransactionType.income, category: '5900')),
      contains('Pendapatan'),
    );
    expect(validateRejectReason(' ab '), isNotNull);
    expect(validateRejectReason('a' * 501), isNotNull);
    expect(validateRejectReason('Bukti kurang'), isNull);
  });

  test(
    'Codec menyimpan nominal integer dan tanggal UTC, menolak format salah',
    () {
      final values = TransactionCodec.draftValues(
        draft(date: DateTime(2026, 3, 2, 15, 30), description: '  ATK  '),
      );
      expect(values['amount'], 150000);
      expect(values['description'], 'ATK');
      expect(
        (values['date'] as Timestamp).toDate().toUtc(),
        DateTime.utc(2026, 3, 2),
      );
      expect(values.containsKey('status'), isFalse);
      final now = Timestamp.fromDate(DateTime.utc(2026, 3, 2));
      final data = {
        ...values,
        'status': 'pending',
        'createdBy': 'u1',
        'createdAt': now,
        'approvedBy': null,
        'approvedAt': null,
        'rejectReason': null,
      };
      final tx = TransactionCodec.fromDocument('t1', data);
      expect(tx.amount, 150000);
      expect(tx.isPending, isTrue);
      expect(tx.canModify('u1'), isTrue);
      expect(tx.canModify('u2'), isFalse);
      for (final bad in [
        {'amount': 1.5},
        {'amount': 0},
        {'status': 'draft'},
        {'type': 'transfer'},
        {'createdAt': null},
      ]) {
        expect(
          () => TransactionCodec.fromDocument('t1', {...data, ...bad}),
          throwsA(isA<TransactionFailure>()),
        );
      }
    },
  );

  test('Controller: filter status, pembuat hanya ubah pending, Finance tidak memutuskan', () async {
    final repo = FakeTransactionsRepository()
      ..items = [
        sampleTransaction(id: 'p'),
        sampleTransaction(id: 'a', status: TransactionStatus.approved),
        sampleTransaction(id: 'o', createdBy: 'other'),
      ];
    addTearDown(repo.dispose);
    final finance = TransactionsController(
      repo,
      companyId: 'c',
      userId: 'test-user',
      role: CompanyRole.finance,
    );
    addTearDown(finance.dispose);
    await pumpEventQueue();
    expect(finance.transactions.length, 3);
    finance.setFilter(TransactionStatus.approved);
    expect(finance.visibleTransactions.map((t) => t.id), ['a']);
    expect(finance.pendingTransactions.length, 2);

    final approved = repo.items.firstWhere((t) => t.id == 'a');
    final others = repo.items.firstWhere((t) => t.id == 'o');
    expect(await finance.update(approved, draft()), isFalse);
    expect(await finance.delete(others), isFalse);
    expect(await finance.approve(repo.items.first), isFalse);
    expect(await finance.reject(repo.items.first, 'Tidak valid'), isFalse);
    expect(repo.calls, isEmpty);

    expect(await finance.create('n1', draft()), isTrue);
    await pumpEventQueue();
    final created = finance.transactions.firstWhere((t) => t.id == 'n1');
    expect(created.status, TransactionStatus.pending);
    expect(await finance.delete(created), isTrue);
    expect(repo.calls, ['create:n1', 'delete:n1']);
  });

  test('Controller Manager: approve/reject pending, alasan wajib', () async {
    final repo = FakeTransactionsRepository()
      ..items = [sampleTransaction(id: 'p1'), sampleTransaction(id: 'p2')];
    addTearDown(repo.dispose);
    final manager = TransactionsController(
      repo,
      companyId: 'c',
      userId: 'm',
      role: CompanyRole.manager,
    );
    addTearDown(manager.dispose);
    await pumpEventQueue();
    final p1 = manager.transactions.firstWhere((t) => t.id == 'p1');
    final p2 = manager.transactions.firstWhere((t) => t.id == 'p2');
    expect(await manager.reject(p2, ' '), isFalse);
    expect(manager.actionError, contains('Alasan'));
    expect(await manager.approve(p1), isTrue);
    expect(await manager.reject(p2, ' Bukti kurang '), isTrue);
    await pumpEventQueue();
    expect(manager.pendingTransactions, isEmpty);
    expect(repo.calls, ['approve:p1', 'reject:p2:Bukti kurang']);
    final approved = manager.transactions.firstWhere((t) => t.id == 'p1');
    expect(await manager.approve(approved), isFalse);
  });

  Future<FakeTransactionsRepository> pumpPage(
    WidgetTester tester, {
    required bool approvals,
    CompanyRole role = CompanyRole.manager,
    List<FinanceTransaction> items = const [],
  }) async {
    final repo = FakeTransactionsRepository()..items = [...items];
    final chart = FakeChartOfAccountsRepository()
      ..accounts = defaultChartOfAccounts;
    addTearDown(repo.dispose);
    addTearDown(chart.dispose);
    final company = CompanyContext(company: testCompany.company, role: role);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: approvals
              ? ApprovalsPage(
                  company: company,
                  userId: 'test-user',
                  repository: repo,
                  chartRepository: chart,
                )
              : TransactionsPage(
                  company: company,
                  userId: 'test-user',
                  repository: repo,
                  chartRepository: chart,
                ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets(
    'Halaman Transaksi: empty state, filter status, form tambah pending',
    (tester) async {
      final repo = await pumpPage(tester, approvals: false);
      expect(find.text('Belum ada transaksi.'), findsOneWidget);

      await tester.tap(find.text('Tambah transaksi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajukan transaksi'));
      await tester.pumpAndSettle();
      expect(find.text('Nominal harus lebih dari Rp 0.'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Nominal (Rp)'),
        '250000',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Keterangan'),
        'Bayar listrik',
      );
      await tester.tap(find.text('Akun Kas/Bank'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1100 · Kas').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kategori (Beban)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5400 · Beban utilitas').last);
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('Ajukan transaksi'),
        find.byType(ListView).last,
        const Offset(0, -200),
      );
      await tester.tap(find.text('Ajukan transaksi'));
      await tester.pumpAndSettle();

      expect(repo.calls, ['create:tx-1']);
      expect(find.text('Bayar listrik'), findsOneWidget);
      expect(find.text('-Rp 250.000'), findsOneWidget);
      expect(find.text('Menunggu'), findsWidgets);
      expect(find.text('Edit'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Disetujui'));
      await tester.pumpAndSettle();
      expect(
        find.text('Tidak ada transaksi dengan status ini.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Transaksi approved dan milik orang lain tidak dapat diedit', (
    tester,
  ) async {
    await pumpPage(
      tester,
      approvals: false,
      items: [
        sampleTransaction(id: 'a', status: TransactionStatus.approved),
        sampleTransaction(
          id: 'o',
          createdBy: 'other',
          description: 'Milik lain',
        ),
      ],
    );
    expect(find.text('Disetujui'), findsWidgets);
    expect(find.text('Milik lain'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Hapus'), findsNothing);
  });

  testWidgets('Approval Manager: setujui dan tolak dengan alasan', (
    tester,
  ) async {
    final repo = await pumpPage(
      tester,
      approvals: true,
      items: [
        sampleTransaction(id: 'p1', description: 'Transaksi satu'),
        sampleTransaction(id: 'p2', description: 'Transaksi dua'),
        sampleTransaction(
          id: 'a',
          status: TransactionStatus.approved,
          description: 'Sudah',
        ),
      ],
    );
    expect(find.text('Sudah'), findsNothing);
    expect(find.text('2 transaksi menunggu'), findsOneWidget);
    await tester.tap(find.text('Setujui').first);
    await tester.pumpAndSettle();
    expect(find.text('1 transaksi menunggu'), findsOneWidget);

    await tester.tap(find.text('Tolak').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Tolak'));
    await tester.pumpAndSettle();
    expect(find.textContaining('minimal'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Nota tidak ada');
    await tester.tap(find.widgetWithText(FilledButton, 'Tolak'));
    await tester.pumpAndSettle();
    expect(
      find.text('Tidak ada transaksi yang menunggu persetujuan.'),
      findsOneWidget,
    );
    expect(repo.calls.last, 'reject:p2:Nota tidak ada');
  });

  testWidgets('Approval Finance: melihat pending tanpa tombol keputusan', (
    tester,
  ) async {
    await pumpPage(
      tester,
      approvals: true,
      role: CompanyRole.finance,
      items: [sampleTransaction(id: 'p1')],
    );
    expect(find.textContaining('Hanya Manager'), findsOneWidget);
    expect(find.text('Setujui'), findsNothing);
    expect(find.text('Tolak'), findsNothing);
  });

  testWidgets('Transaksi layar 320dp teks besar tanpa overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpPage(
      tester,
      approvals: true,
      items: [sampleTransaction(id: 'p1', amount: 999999999999)],
    );
    expect(tester.takeException(), isNull);
  });
}
