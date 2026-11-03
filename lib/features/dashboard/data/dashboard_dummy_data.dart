/// Snapshot contoh statis, bukan hasil perhitungan atau saldo akun sebenarnya.
/// Semua nominal adalah integer Rupiah. Saldo dan arus kas hanya mencakup
/// transaksi disetujui; piutang dan utang disajikan terpisah dari arus kas.
class DashboardSnapshot {
  const DashboardSnapshot({
    required this.company,
    required this.userName,
    required this.period,
    required this.cashBalance,
    required this.income,
    required this.expense,
    required this.receivables,
    required this.payables,
    required this.receivableCount,
    required this.payableCount,
    required this.activity,
    required this.recentTransactions,
  });
  final String company;
  final String userName;
  final String period;
  final int cashBalance;
  final int income;
  final int expense;
  final int receivables;
  final int payables;
  final int receivableCount;
  final int payableCount;
  final List<CashActivity> activity;
  final List<RecentTransaction> recentTransactions;
}

class CashActivity {
  const CashActivity(this.label, this.income, this.expense);
  final String label;
  final int income;
  final int expense;
}

enum TransactionStatus {
  approved('Disetujui'),
  pending('Menunggu'),
  rejected('Ditolak');

  const TransactionStatus(this.label);
  final String label;
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

const dashboardDummyData = DashboardSnapshot(
  company: 'PT Maju Bersama',
  userName: 'Andi',
  period: 'Oktober 2026',
  cashBalance: 48750000,
  income: 32500000,
  expense: 18750000,
  receivables: 12500000,
  payables: 8250000,
  receivableCount: 5,
  payableCount: 3,
  activity: [
    CashActivity('01–07', 6500000, 3500000),
    CashActivity('08–14', 8000000, 5250000),
    CashActivity('15–21', 5000000, 4000000),
    CashActivity('22–31', 13000000, 6000000),
  ],
  recentTransactions: [
    RecentTransaction(
      title: 'Pembayaran proyek website',
      category: 'Pendapatan jasa',
      dateLabel: '31 Okt 2026',
      amount: 7500000,
      isIncome: true,
      status: TransactionStatus.approved,
    ),
    RecentTransaction(
      title: 'Langganan software',
      category: 'Operasional',
      dateLabel: '30 Okt 2026',
      amount: 850000,
      isIncome: false,
      status: TransactionStatus.approved,
    ),
    RecentTransaction(
      title: 'Pembelian perlengkapan',
      category: 'Kebutuhan kantor',
      dateLabel: '30 Okt 2026',
      amount: 1250000,
      isIncome: false,
      status: TransactionStatus.pending,
    ),
  ],
);
