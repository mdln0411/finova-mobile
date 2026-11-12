import 'bill.dart';
import 'receivable.dart';

abstract interface class ReceivablesRepository {
  Stream<List<Receivable>> watchReceivables(String companyId);
  Stream<List<Bill>> watchBills(String companyId);
  String newReceivableId(String companyId);
  Future<void> create(String companyId, String id, ReceivableDraft draft);
  Future<void> update(String companyId, String id, ReceivableDraft draft);
  Future<void> delete(String companyId, String id);
  Future<void> approve(String companyId, String id);
  Future<void> reject(String companyId, String id, String reason);
}
