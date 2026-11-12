import 'package:finova/app/theme/app_theme.dart';
import 'package:finova/features/chart_of_accounts/domain/default_chart_of_accounts.dart';
import 'package:finova/features/company/domain/company.dart';
import 'package:finova/features/receivables/application/receivables_controller.dart';
import 'package:finova/features/receivables/domain/receivable.dart';
import 'package:finova/features/receivables/domain/receivable_status.dart';
import 'package:finova/features/receivables/presentation/receivables_page.dart';
import 'package:finova/features/transactions/domain/bill.dart';
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
      status: TransactionStatus.approved,
      dueDate: due,
      amount: 100000,
    );
    FinanceTransaction payment(
      String id,
      int amount,
      TransactionStatus status,
    ) => FinanceTransaction(
      id: id,
      type: TransactionType.income,
      amount: amount,
      date: DateTime.now(),
      description: 'Pembayaran $id',
      cashAccountId: '1100',
      categoryAccountId: receivableAccountCode,
      status: status,
      createdBy: 'finance',
      createdAt: DateTime.now(),
      receivableId: receivable.id,
    );
    final pendingPayment = payment('pending', 20000, TransactionStatus.pending);
    final approvedPayment = payment(
      'approved',
      40000,
      TransactionStatus.approved,
    );
    final partial = receivable.settlement([pendingPayment, approvedPayment]);
    expect(partial.remaining, 60000);
    expect(
      receivable
          .paymentsFrom([pendingPayment, approvedPayment])
          .map((tx) => tx.id),
      containsAll(['pending', 'approved']),
    );
    final paid = receivable.settlement([
      approvedPayment,
      payment('overpayment', 100000, TransactionStatus.approved),
    ]);
    expect(paid.remaining, 0);
    expect(receivable.statusLabel(partial), 'Dibayar sebagian');
    expect(receivable.statusLabel(paid), 'Lunas');
    final late = sampleReceivable(
      status: TransactionStatus.approved,
      dueDate: DateTime.now().subtract(const Duration(days: 1)),
    );
    expect(late.statusLabel(late.settlement(const [])), 'Terlambat');
    expect(
      sampleReceivable().statusLabel(const BillSettlement(amount: 1, paid: 0)),
      'Menunggu persetujuan',
    );

    Receivable draft({String customer = 'Customer', int amount = 10}) =>
        Receivable(
          id: 'draft',
          customerName: customer,
          number: 'INV',
          amount: amount,
          issueDate: DateTime.utc(2026, 3, 1),
          dueDate: DateTime.utc(2026, 3, 1),
          description: 'Penjualan',
          revenueAccountId: '4100',
          status: TransactionStatus.pending,
          createdBy: 'finance',
          createdAt: DateTime.utc(2026, 3, 1),
        );
    expect(
      draft(customer: ' ').validate(accounts: defaultChartOfAccounts),
      contains('Nama pelanggan'),
    );
    expect(
      draft(amount: 0).validate(accounts: defaultChartOfAccounts),
      contains('Nominal'),
    );
    expect(draft().validate(accounts: defaultChartOfAccounts), isNull);
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
          status: TransactionStatus.approved,
          dueDate: today.add(const Duration(days: 3)),
        ),
        sampleReceivable(
          id: 'late',
          status: TransactionStatus.approved,
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
      find.widgetWithText(TextField, 'Keterangan'),
      find.byType(ListView).last,
      const Offset(0, -180),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Keterangan'),
      'Penjualan bulan ini',
    );
    await tester.dragUntilVisible(
      find.text('Ajukan piutang'),
      find.byType(ListView).last,
      const Offset(0, -180),
    );
    await tester.tap(find.text('Ajukan piutang'));
    await tester.pumpAndSettle();
    expect(page.$1.calls, ['create:receivable-1']);
    expect(page.$1.items.single.revenueAccountId, '4100');
    expect(page.$1.items.single.status, TransactionStatus.pending);
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
            status: TransactionStatus.approved,
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
