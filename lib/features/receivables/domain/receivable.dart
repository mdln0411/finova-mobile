import '../../transactions/domain/bill.dart';
import '../../transactions/domain/finance_transaction.dart';

/// Piutang pelanggan. Saat disetujui: debit akun Piutang, kredit
/// [revenueAccountId]. Pembayaran = transaksi income dengan `receivableId`.
class Receivable extends Bill {
  const Receivable({
    required super.id,
    required this.customerName,
    required super.number,
    required super.amount,
    required super.issueDate,
    required super.dueDate,
    required super.description,
    required this.revenueAccountId,
    required super.status,
    required super.createdBy,
    required super.createdAt,
    super.approvedBy,
    super.approvedAt,
    super.rejectReason,
  });
  final String customerName;
  final String revenueAccountId;

  @override
  String get partyName => customerName;

  @override
  String get counterAccountId => revenueAccountId;

  @override
  TransactionType get paymentType => TransactionType.income;

  @override
  String? linkedBillId(FinanceTransaction tx) => tx.receivableId;
}
