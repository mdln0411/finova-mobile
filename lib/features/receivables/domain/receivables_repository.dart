import '../../transactions/domain/finance_transaction.dart';
import '../../transactions/domain/bill.dart';
import 'receivable.dart';

abstract interface class ReceivablesRepository {
  Stream<List<Receivable>> watchReceivables(String companyId);

  /// Transaksi pemasukan yang tertaut ke piutang (`receivableId`).
  /// Pelunasan dihitung dengan [Bill.settlement].
  Stream<List<FinanceTransaction>> watchPayments(String companyId);
  String newReceivableId(String companyId);

  /// Field yang disimpan: isian pembuat dari [receivable]; status dan
  /// metadata ditetapkan repository.
  Future<void> create(String companyId, Receivable receivable);
  Future<void> update(String companyId, Receivable receivable);
  Future<void> delete(String companyId, String id);
  Future<void> approve(String companyId, String id);
  Future<void> reject(String companyId, String id, String reason);
}
