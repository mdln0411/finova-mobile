import 'package:finova/app/theme/app_theme.dart';
import 'package:finova/features/chart_of_accounts/domain/default_chart_of_accounts.dart';
import 'package:finova/features/company/domain/company.dart';
import 'package:finova/features/receivables/application/receivables_controller.dart';
import 'package:finova/features/receivables/domain/bill.dart';
import 'package:finova/features/receivables/domain/receivable.dart';
import 'package:finova/features/receivables/presentation/receivables_page.dart';
import 'package:finova/features/transactions/domain/finance_transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_chart_of_accounts_repository.dart';
import 'support/fake_company_repository.dart';
import 'support/fake_receivables_repository.dart';
import 'support/fake_transactions_repository.dart';

void main() {
  test('Receivable validates required fields and calculates unpaid status', () {
    final due = DateTime.now().add(const Duration(days: 2));
    final receivable = sampleReceivable(
      status: ReceivableStatus.approved,
      dueDate: due,
      amount: 100000,
    );
    final pendingBill = Bill(
      id: 'pending',
      receivableId: receivable.id,
      amount: 20000,
      date: DateTime.now(),
      description: 'Pembayaran menunggu',
      status: TransactionStatus.pending,
      createdBy: 'finance',
      createdAt: DateTime.now(),
    );
    final approvedBill = Bill(
      id: 'approved',
      receivableId: receivable.id,
      amount: 40000,
      date: DateTime.now(),
      description: 'Pembayaran disetujui',
      status: TransactionStatus.approved,
      createdBy: 'finance',
      createdAt: DateTime.now(),
    );
    expect(receivable.remainingAmount([pendingBill, approvedBill]), 60000);
    expect(
      receivable.remainingAmount([
        approvedBill,
        Bill(
          id: 'overpayment',
          receivableId: receivable.id,
          amount: 100000,
          date: DateTime.now(),
          description: 'Pembayaran lebih',
          status: TransactionStatus.approved,
          createdBy: 'finance',
          createdAt: DateTime.now(),
        ),
      ]),
      0,
    );
    expect(receivable.paymentStatus(60000), 'Belum lunas');
    expect(receivable.paymentStatus(0), 'Lunas');
    expect(
      sampleReceivable(
        status: ReceivableStatus.approved,
        dueDate: DateTime.now().subtract(const Duration(days: 1)),
      ).paymentStatus(100),
      'Terlambat',
    );
    expect(
      ReceivableDraft(
        customerName: ' ',
        number: 'INV',
        amount: 10,
        revenueAccountId: '4100',
        dueDate: DateTime.utc(2026, 3, 1),
        description: '',
      ).validate(),
      contains('Nama customer'),
    );
    expect(
      ReceivableDraft(
        customerName: 'Customer',
        number: 'INV',
        amount: 0,
        revenueAccountId: '4100',
        dueDate: DateTime.utc(2026, 3, 1),
        description: '',
      ).validate(),
      contains('Jumlah'),
    );
  });

  test(
    'Controller membatasi keputusan kepada Manager dan validasi alasan',
    () async {
      final repository = FakeReceivablesRepository()
        ..items = [sampleReceivable()];
      addTearDown(repository.dispose);
      final finance = ReceivablesController(
        repository,
        companyId: 'company',
        userId: 'test-user',
        role: CompanyRole.finance,
      );
      addTearDown(finance.dispose);
      await pumpEventQueue();
      expect(await finance.approve(finance.receivables.first), isFalse);
      expect(repository.calls, isEmpty);

      final manager = ReceivablesController(
        repository,
        companyId: 'company',
        userId: 'manager',
        role: CompanyRole.manager,
      );
      addTearDown(manager.dispose);
      await pumpEventQueue();
      final receivable = manager.receivables.first;
      expect(await manager.reject(receivable, ' '), isFalse);
      expect(manager.actionError, contains('Alasan'));
      expect(await manager.approve(receivable), isTrue);
      expect(repository.calls, ['approve:r1']);
    },
  );

  Future<(FakeReceivablesRepository, FakeTransactionsRepository)> pumpPage(
    WidgetTester tester, {
    required CompanyRole role,
    required List<Receivable> receivables,
  }) async {
    final repository = FakeReceivablesRepository()..items = receivables;
    final transactions = FakeTransactionsRepository();
    final chart = FakeChartOfAccountsRepository()
      ..accounts = defaultChartOfAccounts;
    addTearDown(repository.dispose);
    addTearDown(transactions.dispose);
    addTearDown(chart.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ReceivablesPage(
            company: CompanyContext(company: testCompany.company, role: role),
            userId: role == CompanyRole.manager ? 'manager' : 'test-user',
            repository: repository,
            transactionsRepository: transactions,
            chartRepository: chart,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (repository, transactions);
  }

  testWidgets('Halaman Piutang menampilkan bagian jatuh tempo dan terlambat', (
    tester,
  ) async {
    final today = DateTime.now();
    await pumpPage(
      tester,
      role: CompanyRole.finance,
      receivables: [
        sampleReceivable(
          id: 'soon',
          status: ReceivableStatus.approved,
          dueDate: today.add(const Duration(days: 3)),
        ),
        sampleReceivable(
          id: 'late',
          status: ReceivableStatus.approved,
          dueDate: today.subtract(const Duration(days: 1)),
        ),
      ],
    );
    await tester.dragUntilVisible(
      find.text('Semua piutang'),
      find.byType(ListView),
      const Offset(0, -180),
    );
    expect(find.text('Jatuh tempo ≤ 7 hari'), findsOneWidget);
    expect(find.text('Terlambat'), findsWidgets);
    expect(find.text('Semua piutang'), findsOneWidget);
    expect(find.text('Customer Finova'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Finance menambahkan piutang dengan akun Pendapatan', (
    tester,
  ) async {
    final page = await pumpPage(
      tester,
      role: CompanyRole.finance,
      receivables: const [],
    );
    await tester.tap(find.text('Tambah piutang'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nama customer'),
      'Customer Baru',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Nomor piutang'),
      'INV-200',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Jumlah (Rp)'),
      '200000',
    );
    await tester.tap(find.text('Akun Pendapatan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4100 · Penjualan barang').last);
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Ajukan piutang'),
      find.byType(ListView).last,
      const Offset(0, -180),
    );
    await tester.tap(find.text('Ajukan piutang'));
    await tester.pumpAndSettle();
    expect(page.$1.calls, ['create:receivable-1']);
    expect(page.$1.items.single.revenueAccountId, '4100');
    expect(page.$1.items.single.status, ReceivableStatus.pending);
  });

  testWidgets(
    'Manager dapat menyetujui piutang dan Finance mencatat pembayaran',
    (tester) async {
      final pendingRepository = await pumpPage(
        tester,
        role: CompanyRole.manager,
        receivables: [sampleReceivable()],
      );
      await tester.ensureVisible(find.text('Customer Finova').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Customer Finova').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Setujui'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Setujui'));
      await tester.pumpAndSettle();
      expect(pendingRepository.$1.calls, ['approve:r1']);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      final paymentPage = await pumpPage(
        tester,
        role: CompanyRole.finance,
        receivables: [
          sampleReceivable(
            status: ReceivableStatus.approved,
            dueDate: DateTime.now().add(const Duration(days: 3)),
          ),
        ],
      );
      await tester.ensureVisible(find.text('Customer Finova').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Customer Finova').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Catat pembayaran'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Catat pembayaran'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '25000');
      await tester.tap(find.text('Ajukan pembayaran'));
      await tester.pumpAndSettle();
      expect(paymentPage.$2.calls, ['create:tx-1']);
      expect(
        paymentPage.$2.items.single.receivableId,
        paymentPage.$1.items.single.id,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
