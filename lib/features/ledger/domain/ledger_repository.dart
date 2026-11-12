import '../../transactions/domain/finance_transaction.dart';

/// Sumber data ledger. Ledger tidak disimpan; dihitung dari transaksi ini.
abstract interface class LedgerRepository {
  /// Hanya transaksi berstatus `approved`.
  Stream<List<FinanceTransaction>> watchApprovedTransactions(String companyId);
}
