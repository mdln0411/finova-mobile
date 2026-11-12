import 'package:finova/app/theme/app_theme.dart';
import 'package:finova/features/accounts/presentation/accounts_page.dart';
import 'package:finova/features/chart_of_accounts/domain/chart_account.dart';
import 'package:finova/features/chart_of_accounts/domain/default_chart_of_accounts.dart';
import 'package:finova/features/ledger/application/ledger_controller.dart';
import 'package:finova/features/ledger/domain/ledger_calculator.dart';
import 'package:finova/features/ledger/presentation/ledger_page.dart';
import 'package:finova/features/receivables/domain/receivable.dart';
import 'package:finova/features/transactions/domain/finance_transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_chart_of_accounts_repository.dart';
import 'support/fake_company_repository.dart';
import 'support/fake_ledger_repository.dart';

ChartAccount account(String code) =>
    defaultChartOfAccounts.firstWhere((a) => a.code == code);

FinanceTransaction tx(
  String id, {
  TransactionType type = TransactionType.expense,
  int amount = 100000,
  DateTime? date,
  String cash = '1100',
  String? category,
  String? receivableId,
  TransactionStatus status = TransactionStatus.approved,
  DateTime? createdAt,
}) => FinanceTransaction(
  id: id,
  type: type,
  amount: amount,
  date: date ?? DateTime.utc(2026, 3, 1),
  description: 'Transaksi $id',
  cashAccountId: cash,
  categoryAccountId:
      category ?? (type == TransactionType.income ? '4100' : '5900'),
  receivableId: receivableId,
  status: status,
  createdBy: 'test-user',
  createdAt: createdAt ?? DateTime.utc(2026, 3, 1, 8),
);

void main() {
  group('LedgerCalculator.postingOf', () {
    test('income: debit Kas/Bank, kredit Pendapatan', () {
      final p = LedgerCalculator.postingOf(
        tx('a', type: TransactionType.income, cash: '1200', category: '4200'),
      );
      expect(p.debit, '1200');
      expect(p.credit, '4200');
    });

    test('piutang approved mendebit Piutang, pembayaran mengkreditnya', () {
      final receivable = Receivable(
        id: 'r1',
        customerName: 'Customer Finova',
        number: 'INV-001',
        amount: 150000,
        issueDate: DateTime.utc(2026, 3, 1),
        dueDate: DateTime.utc(2026, 3, 10),
        description: 'Penjualan barang',
        revenueAccountId: '4100',
        status: TransactionStatus.approved,
        createdBy: 'test-user',
        createdAt: DateTime.utc(2026, 3, 1),
      );
      final payment = tx(
        'payment',
        type: TransactionType.income,
        amount: 50000,
        cash: '1100',
        category: '1300',
        receivableId: 'r1',
      );
      final paymentPosting = LedgerCalculator.postingOf(payment);
      expect(paymentPosting.debit, '1100');
      expect(paymentPosting.credit, '1300');
      expect(
        LedgerCalculator.forAccount(
          account('1300'),
          [payment],
          receivables: [receivable],
        ).closingBalance,
        100000,
      );
      expect(
        LedgerCalculator.forAccount(
          account('4100'),
          [payment],
          receivables: [receivable],
        ).closingBalance,
        150000,
      );
    });

    test('expense: debit Beban, kredit Kas/Bank', () {
      final p = LedgerCalculator.postingOf(tx('a', category: '5200'));
      expect(p.debit, '5200');
      expect(p.credit, '1100');
    });
  });

  group('LedgerCalculator.forAccount', () {
    final items = [
      tx(
        'in1',
        type: TransactionType.income,
        amount: 1000000,
        date: DateTime.utc(2026, 3, 1),
      ),
      tx('ex1', amount: 250000, date: DateTime.utc(2026, 3, 5)),
      tx(
        'in2',
        type: TransactionType.income,
        amount: 500000,
        date: DateTime.utc(2026, 3, 10),
      ),
      tx('ex2', amount: 100000, date: DateTime.utc(2026, 3, 20)),
    ];

    test('Akun aset (saldo normal debit): saldo berjalan dan saldo akhir', () {
      final ledger = LedgerCalculator.forAccount(account('1100'), items);
      expect(ledger.entries.map((e) => e.sourceId), [
        'in1',
        'ex1',
        'in2',
        'ex2',
      ]);
      expect(ledger.entries.map((e) => e.debit), [1000000, 0, 500000, 0]);
      expect(ledger.entries.map((e) => e.credit), [0, 250000, 0, 100000]);
      expect(ledger.entries.map((e) => e.balance), [
        1000000,
        750000,
        1250000,
        1150000,
      ]);
      expect(ledger.openingBalance, 0);
      expect(ledger.totalDebit, 1500000);
      expect(ledger.totalCredit, 350000);
      expect(ledger.closingBalance, 1150000);
    });

    test('Akun pendapatan (saldo normal kredit) bertambah saat dikredit', () {
      final ledger = LedgerCalculator.forAccount(account('4100'), items);
      expect(ledger.entries.map((e) => e.credit), [1000000, 500000]);
      expect(ledger.entries.map((e) => e.debit), [0, 0]);
      expect(ledger.closingBalance, 1500000);
    });

    test('Akun beban (saldo normal debit) bertambah saat didebit', () {
      final ledger = LedgerCalculator.forAccount(account('5900'), items);
      expect(ledger.entries.map((e) => e.debit), [250000, 100000]);
      expect(ledger.closingBalance, 350000);
    });

    test('Akun liabilitas/ekuitas memakai saldo normal kredit', () {
      // Transaksi sintetis untuk menguji arah saldo, bukan alur form.
      final loan = tx(
        'loan',
        type: TransactionType.income,
        amount: 2000000,
        category: '2200',
      );
      final capital = tx(
        'cap',
        type: TransactionType.income,
        amount: 3000000,
        category: '3100',
      );
      final repay = tx('repay', amount: 500000, category: '2200');
      expect(
        LedgerCalculator.forAccount(account('2200'), [
          loan,
          repay,
        ]).closingBalance,
        1500000,
      );
      expect(
        LedgerCalculator.forAccount(account('3100'), [capital]).closingBalance,
        3000000,
      );
    });

    test('Saldo kas bisa negatif bila pengeluaran melebihi pemasukan', () {
      final ledger = LedgerCalculator.forAccount(account('1100'), [
        tx('ex', amount: 300000),
      ]);
      expect(ledger.closingBalance, -300000);
    });

    test('Pending dan rejected tidak memengaruhi ledger', () {
      final ledger = LedgerCalculator.forAccount(account('1100'), [
        ...items,
        tx(
          'p',
          type: TransactionType.income,
          amount: 9000000,
          status: TransactionStatus.pending,
        ),
        tx('r', amount: 7000000, status: TransactionStatus.rejected),
      ]);
      expect(ledger.entries.length, 4);
      expect(ledger.closingBalance, 1150000);
    });

    test(
      'Filter tanggal inklusif dengan saldo awal dari periode sebelumnya',
      () {
        final ledger = LedgerCalculator.forAccount(
          account('1100'),
          items,
          from: DateTime(2026, 3, 5, 23, 59),
          to: DateTime(2026, 3, 10),
        );
        expect(ledger.openingBalance, 1000000);
        expect(ledger.entries.map((e) => e.sourceId), ['ex1', 'in2']);
        expect(ledger.entries.map((e) => e.balance), [750000, 1250000]);
        expect(ledger.closingBalance, 1250000);
      },
    );

    test('Rentang tanpa mutasi: saldo akhir = saldo awal', () {
      final ledger = LedgerCalculator.forAccount(
        account('1100'),
        items,
        from: DateTime.utc(2026, 3, 11),
        to: DateTime.utc(2026, 3, 19),
      );
      expect(ledger.entries, isEmpty);
      expect(ledger.openingBalance, 1250000);
      expect(ledger.closingBalance, 1250000);
    });

    test('Hanya batas akhir: transaksi setelahnya diabaikan', () {
      final ledger = LedgerCalculator.forAccount(
        account('1100'),
        items,
        to: DateTime.utc(2026, 3, 5),
      );
      expect(ledger.entries.length, 2);
      expect(ledger.closingBalance, 750000);
    });

    test(
      'Urutan stabil: tanggal, waktu dibuat, lalu ID; input tidak berubah',
      () {
        final day = DateTime.utc(2026, 3, 1);
        final input = [
          tx('b', date: day, createdAt: DateTime.utc(2026, 3, 1, 9)),
          tx('c', date: day, createdAt: DateTime.utc(2026, 3, 1, 8)),
          tx('a', date: day, createdAt: DateTime.utc(2026, 3, 1, 9)),
        ];
        final ledger = LedgerCalculator.forAccount(account('5900'), input);
        expect(ledger.entries.map((e) => e.sourceId), ['c', 'a', 'b']);
        expect(input.map((e) => e.id), ['b', 'c', 'a']);
      },
    );

    test('Akun tanpa mutasi menghasilkan ledger kosong bernilai nol', () {
      final ledger = LedgerCalculator.forAccount(account('1400'), items);
      expect(ledger.entries, isEmpty);
      expect(ledger.closingBalance, 0);
    });

    test('Nominal besar tetap presisi (integer, tanpa floating-point)', () {
      final ledger = LedgerCalculator.forAccount(account('1100'), [
        tx(
          'big1',
          type: TransactionType.income,
          amount: TransactionLimits.maxAmount,
        ),
        tx('small', amount: 1, date: DateTime.utc(2026, 3, 2)),
      ]);
      expect(ledger.closingBalance, TransactionLimits.maxAmount - 1);
    });
  });

  group('LedgerCalculator.balances', () {
    test('Total debit = total kredit (double-entry seimbang)', () {
      final items = [
        tx('i', type: TransactionType.income, amount: 800000, cash: '1200'),
        tx('e', amount: 300000, category: '5300'),
        tx('x', amount: 50000, status: TransactionStatus.rejected),
      ];
      final balances = LedgerCalculator.balances(defaultChartOfAccounts, items);
      expect(balances['1100'], -300000);
      expect(balances['1200'], 800000);
      expect(balances['4100'], 800000);
      expect(balances['5300'], 300000);
      expect(balances['5900'], 0);
      var debit = 0;
      var credit = 0;
      for (final a in defaultChartOfAccounts) {
        final value = balances[a.code]!;
        a.normalBalance == BalanceSide.debit ? debit += value : credit += value;
      }
      expect(debit, credit);
    });

    test('Akun yang tidak diminta diabaikan', () {
      final balances = LedgerCalculator.balances(
        [account('1100')],
        [tx('e', amount: 1000)],
      );
      expect(balances, {'1100': -1000});
    });
  });

  test('cashBankAccounts: klasifikasi 11xx/12xx termasuk nonaktif', () {
    const inactive = ChartAccount(
      code: '1150',
      name: 'Kas kecil lama',
      type: AccountType.asset,
      normalBalance: BalanceSide.debit,
      isPosting: true,
      parentCode: '1000',
      isActive: false,
    );
    final all = [...defaultChartOfAccounts, inactive];
    final result = cashBankAccounts(all);
    // 1200 = Bank; 1300 = Piutang usaha (bukan Kas/Bank).
    expect(result.map((a) => a.code), ['1100', '1150', '1200']);
    expect(all.where(isCashBankAccount).length, 3);
    // Form transaksi hanya menawarkan yang aktif.
    expect(
      all.where((a) => isCashBankAccount(a) && a.isActive).map((a) => a.code),
      ['1100', '1200'],
    );
  });

  test(
    'LedgerController memuat transaksi approved dan menyetel filter',
    () async {
      final repo = FakeLedgerRepository()
        ..items = [
          tx('a', type: TransactionType.income, amount: 500000),
          tx('p', amount: 100000, status: TransactionStatus.pending),
        ];
      final controller = LedgerController(repo, companyId: 'c1');
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);
      expect(controller.loading, isFalse);
      expect(controller.transactions.map((t) => t.id), ['a']);
      expect(controller.ledgerFor(defaultChartOfAccounts), isNull);
      controller.selectAccount('1100');
      controller.setRange(DateTime(2026, 3, 1, 14), DateTime(2026, 3, 31));
      expect(controller.from, DateTime.utc(2026, 3, 1));
      expect(
        controller.ledgerFor(defaultChartOfAccounts)!.closingBalance,
        500000,
      );
    },
  );

  group('Halaman', () {
    late FakeLedgerRepository repo;
    late FakeChartOfAccountsRepository chart;

    setUp(() {
      repo = FakeLedgerRepository()
        ..items = [
          tx('in', type: TransactionType.income, amount: 1000000),
          tx(
            'bank',
            type: TransactionType.income,
            amount: 2500000,
            cash: '1200',
          ),
          tx('ex', amount: 250000, date: DateTime.utc(2026, 3, 2)),
          tx('pending', amount: 9000000, status: TransactionStatus.pending),
        ];
      chart = FakeChartOfAccountsRepository()
        ..accounts = defaultChartOfAccounts;
    });

    Widget host(Widget child) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    );

    testWidgets('Kas & Bank menampilkan saldo per akun dan total', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          AccountsPage(
            company: testCompany,
            repository: repo,
            chartRepository: chart,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Total Kas & Bank'), findsOneWidget);
      expect(find.text('Rp 3.250.000'), findsOneWidget);
      expect(find.text('Rp 750.000'), findsOneWidget);
      expect(find.text('Rp 2.500.000'), findsOneWidget);
      expect(find.text('Kas'), findsOneWidget);
      expect(find.text('Bank'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Kas & Bank: akun nonaktif berlabel dan tetap masuk total', (
      tester,
    ) async {
      chart.accounts = [
        ...defaultChartOfAccounts,
        const ChartAccount(
          code: '1150',
          name: 'Kas kecil lama',
          type: AccountType.asset,
          normalBalance: BalanceSide.debit,
          isPosting: true,
          parentCode: '1000',
          isActive: false,
        ),
      ];
      repo.items = [
        ...repo.items,
        tx('old', type: TransactionType.income, amount: 400000, cash: '1150'),
      ];
      await tester.pumpWidget(
        host(
          AccountsPage(
            company: testCompany,
            repository: repo,
            chartRepository: chart,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1150 · Nonaktif'), findsOneWidget);
      expect(find.text('Rp 400.000'), findsOneWidget);
      expect(find.text('Rp 3.650.000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Kas & Bank menampilkan error dan dapat dicoba ulang', (
      tester,
    ) async {
      repo.readFailure = const TransactionFailure('Akses buku besar ditolak.');
      await tester.pumpWidget(
        host(
          AccountsPage(
            company: testCompany,
            repository: repo,
            chartRepository: chart,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Akses buku besar ditolak.'), findsOneWidget);
      repo.readFailure = null;
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('Rp 3.250.000'), findsOneWidget);
    });

    testWidgets('Buku Besar: pilih akun lalu tampil entri dan saldo akhir', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        host(
          LedgerPage(
            company: testCompany,
            repository: repo,
            chartRepository: chart,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pilih akun untuk melihat buku besar.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ledger-account')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('1100 · Kas').last);
      await tester.pumpAndSettle();
      expect(find.text('Transaksi in'), findsOneWidget);
      expect(find.text('Transaksi ex'), findsOneWidget);
      expect(find.text('Transaksi pending'), findsNothing);
      expect(find.text('Saldo Rp 750.000'), findsOneWidget);
      expect(find.text('Rp 750.000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
