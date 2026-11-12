import 'finance_transaction.dart';

abstract interface class TransactionsRepository {
  /// Seluruh transaksi perusahaan, terbaru lebih dulu.
  Stream<List<FinanceTransaction>> watchTransactions(String companyId);

  /// ID dibuat sekali per form agar retry tidak menggandakan transaksi.
  String newTransactionId(String companyId);

  /// Membuat transaksi `pending`. Idempoten untuk ID yang sama.
  Future<void> create(String companyId, String id, TransactionDraft draft);

  /// Hanya pembuat dan hanya selama `pending` (ditegakkan Rules).
  Future<void> update(String companyId, String id, TransactionDraft draft);
  Future<void> delete(String companyId, String id);

  /// Hanya Manager dan hanya transaksi `pending` (ditegakkan Rules).
  Future<void> approve(String companyId, String id);
  Future<void> reject(String companyId, String id, String reason);
}
