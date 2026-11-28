import 'package:finova/features/chart_of_accounts/domain/default_chart_of_accounts.dart';
import 'package:finova/features/dashboard/domain/dashboard_calculator.dart';
import 'package:finova/features/receivables/domain/receivable.dart';
import 'package:finova/features/transactions/domain/finance_transaction.dart';
import 'package:flutter_test/flutter_test.dart';

FinanceTransaction tx(
  String id, {
  TransactionType type = TransactionType.expense,
  int amount = 100000,
  required DateTime date,
  String cash = '1100',
  String? receivableId,
  TransactionStatus status = TransactionStatus.approved,
}) => FinanceTransaction(
  id: id,
  type: type,
  amount: amount,
  date: date,
  description: 'Transaksi $id',
  cashAccountId: cash,
  categoryAccountId: type == TransactionType.income ? '4100' : '5900',
  receivableId: receivableId,
  status: status,
  createdBy: 'test-user',
  createdAt: date,
);

Receivable receivable(
  String id, {
  int amount = 500000,
  TransactionStatus status = TransactionStatus.approved,
}) => Receivable(
  id: id,
  customerName: 'Pelanggan $id',
  number: 'INV-$id',
  amount: amount,
  issueDate: DateTime.utc(2026, 11, 1),
  dueDate: DateTime.utc(2026, 11, 30),
  description: 'Tagihan $id',
  revenueAccountId: '4100',
  status: status,
  createdBy: 'test-user',
  createdAt: DateTime.utc(2026, 11, 1),
);

void main() {
  final today = DateTime(2026, 11, 28);

  test('data kosong menghasilkan nol tanpa aktivitas', () {
    final s = DashboardCalculator.build(
      accounts: defaultChartOfAccounts,
      transactions: const [],
      receivables: const [],
      today: today,
    );
    expect(s.period, 'November 2026');
    expect(s.hasCashAccounts, isTrue);
    expect(s.cashBalance, 0);
    expect(s.income, 0);
    expect(s.expense, 0);
    expect(s.activity, isEmpty);
    expect(s.recentTransactions, isEmpty);
  });

  test('tanpa akun Kas/Bank, saldo ditandai belum tersedia', () {
    final s = DashboardCalculator.build(
      accounts: const [],
      transactions: const [],
      receivables: const [],
      today: today,
    );
    expect(s.hasCashAccounts, isFalse);
  });

  test('saldo semua periode, arus kas hanya bulan berjalan dan approved', () {
    final s = DashboardCalculator.build(
      accounts: defaultChartOfAccounts,
      transactions: [
        tx(
          'old',
          type: TransactionType.income,
          amount: 1000000,
          date: DateTime.utc(2026, 10, 15),
        ),
        tx(
          'in',
          type: TransactionType.income,
          amount: 700000,
          date: DateTime.utc(2026, 11, 3),
        ),
        tx(
          'out',
          amount: 200000,
          date: DateTime.utc(2026, 11, 20),
          cash: '1200',
        ),
        tx(
          'pending',
          type: TransactionType.income,
          amount: 999,
          date: DateTime.utc(2026, 11, 5),
          status: TransactionStatus.pending,
        ),
      ],
      receivables: const [],
      today: today,
    );
    expect(s.cashBalance, 1000000 + 700000 - 200000);
    expect(s.income, 700000);
    expect(s.expense, 200000);
    expect(s.activity.map((a) => a.label), [
      '01–07',
      '08–14',
      '15–21',
      '22–30',
    ]);
    expect(s.activity[0].income, 700000);
    expect(s.activity[2].expense, 200000);
  });

  test('transaksi terbaru urut tanggal menurun, dibatasi, nama kategori', () {
    final s = DashboardCalculator.build(
      accounts: defaultChartOfAccounts,
      transactions: [
        for (var d = 1; d <= 7; d++) tx('t$d', date: DateTime.utc(2026, 11, d)),
      ],
      receivables: const [],
      today: today,
    );
    expect(s.recentTransactions, hasLength(5));
    expect(s.recentTransactions.first.title, 'Transaksi t7');
    expect(s.recentTransactions.first.dateLabel, '7 Nov 2026');
    final category = defaultChartOfAccounts
        .firstWhere((a) => a.code == '5900')
        .name;
    expect(s.recentTransactions.first.category, category);
  });

  test('piutang: hanya approved dan sisa setelah pembayaran approved', () {
    final s = DashboardCalculator.build(
      accounts: defaultChartOfAccounts,
      transactions: [
        tx(
          'pay1',
          type: TransactionType.income,
          amount: 200000,
          date: DateTime.utc(2026, 11, 10),
          receivableId: 'a',
        ),
        tx(
          'pay2',
          type: TransactionType.income,
          amount: 300000,
          date: DateTime.utc(2026, 11, 10),
          receivableId: 'b',
        ),
      ],
      receivables: [
        receivable('a'),
        receivable('b', amount: 300000),
        receivable('c', status: TransactionStatus.pending),
      ],
      today: today,
    );
    expect(s.receivables, 300000);
    expect(s.receivableCount, 1);
  });
}
