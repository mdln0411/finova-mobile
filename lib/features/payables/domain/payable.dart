import '../../transactions/domain/bill.dart';
import '../../transactions/domain/finance_transaction.dart';

/// Utang pemasok. Saat disetujui: debit [expenseAccountId], kredit akun
/// Utang. Pembayaran = transaksi expense dengan `payableId`.
class Payable extends Bill {
  const Payable({
    required super.id,
    required this.supplierName,
    required super.number,
    required super.amount,
    required super.issueDate,
    required super.dueDate,
    required super.description,
    required this.expenseAccountId,
    required super.status,
    required super.createdBy,
    required super.createdAt,
    super.approvedBy,
    super.approvedAt,
    super.rejectReason,
  });
  final String supplierName;
  final String expenseAccountId;

  @override
  String get partyName => supplierName;

  @override
  String get counterAccountId => expenseAccountId;

  @override
  TransactionType get paymentType => TransactionType.expense;

  @override
  String? linkedBillId(FinanceTransaction tx) => tx.payableId;
}
