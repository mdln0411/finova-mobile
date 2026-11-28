import '../../../core/utils/date_format.dart';
import '../../chart_of_accounts/domain/chart_account.dart';
import '../../ledger/domain/ledger_calculator.dart';
import '../../receivables/domain/receivable.dart';
import '../../transactions/domain/finance_transaction.dart';
import 'dashboard_snapshot.dart';

const _monthNames = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

/// Menyusun [DashboardSnapshot] dari data mentah. Fungsi murni: tanpa
/// Firebase, sehingga mudah diuji.
abstract final class DashboardCalculator {
  static DashboardSnapshot build({
    required List<ChartAccount> accounts,
    required List<FinanceTransaction> transactions,
    required List<Receivable> receivables,
    required DateTime today,
    int recentLimit = 5,
  }) {
    final approved = [
      for (final tx in transactions)
        if (tx.status == TransactionStatus.approved) tx,
    ];

    final cashAccounts = cashBankAccounts(accounts);
    final cashBalance = LedgerCalculator.balances(
      cashAccounts,
      approved,
    ).values.fold(0, (sum, value) => sum + value);

    final year = today.year;
    final month = today.month;
    final lastDay = DateTime.utc(year, month + 1, 0).day;
    final inPeriod = [
      for (final tx in approved)
        if (tx.date.year == year && tx.date.month == month) tx,
    ];
    int total(Iterable<FinanceTransaction> items, TransactionType type) => items
        .where((tx) => tx.type == type)
        .fold(0, (sum, tx) => sum + tx.amount);

    String two(int day) => day.toString().padLeft(2, '0');
    final weeks = [(1, 7), (8, 14), (15, 21), (22, lastDay)];
    final activity = [
      for (final (start, end) in weeks)
        () {
          final items = inPeriod.where(
            (tx) => tx.date.day >= start && tx.date.day <= end,
          );
          return CashActivity(
            '${two(start)}–${two(end)}',
            total(items, TransactionType.income),
            total(items, TransactionType.expense),
          );
        }(),
    ];

    var receivableTotal = 0;
    var receivableCount = 0;
    for (final r in receivables) {
      if (!r.isApproved) continue;
      final remaining = r.settlement(approved).remaining;
      if (remaining == 0) continue;
      receivableTotal += remaining;
      receivableCount++;
    }

    final names = {for (final a in accounts) a.code: a.name};
    final recent = [...approved]
      ..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
      });

    return DashboardSnapshot(
      period: '${_monthNames[month - 1]} $year',
      hasCashAccounts: cashAccounts.isNotEmpty,
      cashBalance: cashBalance,
      income: total(inPeriod, TransactionType.income),
      expense: total(inPeriod, TransactionType.expense),
      receivables: receivableTotal,
      receivableCount: receivableCount,
      activity: inPeriod.isEmpty ? const [] : activity,
      recentTransactions: [
        for (final tx in recent.take(recentLimit))
          RecentTransaction(
            title: tx.description,
            category: names[tx.categoryAccountId] ?? tx.categoryAccountId,
            dateLabel: formatShortDate(tx.date),
            amount: tx.amount,
            isIncome: tx.type == TransactionType.income,
            status: tx.status,
          ),
      ],
    );
  }
}
