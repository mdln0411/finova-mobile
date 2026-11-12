import '../../transactions/domain/bill.dart';
import '../../transactions/domain/finance_transaction.dart';
import 'receivable.dart';

class ReceivableFailure implements Exception {
  const ReceivableFailure(this.message);
  final String message;
}

/// Aturan tampilan dan alur modul piutang di atas [Receivable]/[Bill].
extension ReceivableWorkflow on Receivable {
  bool get isPending => status == TransactionStatus.pending;

  bool canModify(String? uid) => isPending && uid != null && createdBy == uid;

  /// Transaksi pembayaran yang tertaut ke piutang ini (semua status),
  /// terbaru lebih dulu. Sisa tagihan tetap dihitung lewat [Bill.settlement].
  List<FinanceTransaction> paymentsFrom(Iterable<FinanceTransaction> items) =>
      items
          .where((tx) => tx.type == paymentType && linkedBillId(tx) == id)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  /// Status tagihan: persetujuan dulu, lalu pelunasan dan keterlambatan.
  String statusLabel(BillSettlement settlement, {DateTime? today}) {
    if (status == TransactionStatus.pending) return 'Menunggu persetujuan';
    if (status == TransactionStatus.rejected) return status.label;
    if (isOverdue(today ?? DateTime.now(), settlement)) return 'Terlambat';
    return settlement.status.label;
  }
}
