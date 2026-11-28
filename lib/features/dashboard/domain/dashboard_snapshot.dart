import '../../transactions/domain/finance_transaction.dart';

/// Ringkasan dashboard. Semua nominal integer Rupiah. Saldo dan arus kas
/// hanya dari transaksi `approved`; piutang disajikan terpisah dari arus kas.
class DashboardSnapshot {
  const DashboardSnapshot({
    required this.period,
    required this.hasCashAccounts,
    required this.cashBalance,
    required this.income,
    required this.expense,
    required this.receivables,
    required this.receivableCount,
    required this.activity,
    required this.recentTransactions,
  });

  /// Label periode berjalan, mis. `November 2026`.
  final String period;

  /// False bila perusahaan belum punya akun Kas/Bank di COA.
  final bool hasCashAccounts;
  final int cashBalance;

  /// Pemasukan dan pengeluaran disetujui pada [period].
  final int income;
  final int expense;

  /// Sisa piutang disetujui yang belum lunas.
  final int receivables;
  final int receivableCount;

  /// Arus kas per minggu pada [period].
  final List<CashActivity> activity;
  final List<RecentTransaction> recentTransactions;
}

class CashActivity {
  const CashActivity(this.label, this.income, this.expense);
  final String label;
  final int income;
  final int expense;
}

class RecentTransaction {
  const RecentTransaction({
    required this.title,
    required this.category,
    required this.dateLabel,
    required this.amount,
    required this.isIncome,
    required this.status,
  });
  final String title;
  final String category;
  final String dateLabel;
  final int amount;
  final bool isIncome;
  final TransactionStatus status;
}
