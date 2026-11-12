import '../../transactions/domain/finance_transaction.dart';

/// Pembayaran piutang yang direpresentasikan oleh transaksi income terkait.
class Bill {
  const Bill({
    required this.id,
    required this.receivableId,
    required this.amount,
    required this.date,
    required this.description,
    required this.status,
    required this.createdBy,
    required this.createdAt,
  });

  factory Bill.fromTransaction(FinanceTransaction transaction) {
    final receivableId = transaction.receivableId;
    if (receivableId == null || transaction.categoryAccountId != '1300') {
      throw const TransactionFailure('Transaksi ini bukan pembayaran piutang.');
    }
    return Bill(
      id: transaction.id,
      receivableId: receivableId,
      amount: transaction.amount,
      date: transaction.date,
      description: transaction.description,
      status: transaction.status,
      createdBy: transaction.createdBy,
      createdAt: transaction.createdAt,
    );
  }

  final String id;
  final String receivableId;
  final int amount;
  final DateTime date;
  final String description;
  final TransactionStatus status;
  final String createdBy;
  final DateTime createdAt;

  bool get isApproved => status == TransactionStatus.approved;
}
