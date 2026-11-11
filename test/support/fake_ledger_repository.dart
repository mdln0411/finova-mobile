import 'dart:async';

import 'package:finova/features/ledger/domain/ledger_repository.dart';
import 'package:finova/features/transactions/domain/finance_transaction.dart';

/// Meniru query Firestore: hanya meneruskan transaksi `approved`.
class FakeLedgerRepository implements LedgerRepository {
  List<FinanceTransaction> items = [];
  TransactionFailure? readFailure;
  final events = StreamController<List<FinanceTransaction>>.broadcast();

  List<FinanceTransaction> get _approved => List.unmodifiable(
    items.where((tx) => tx.status == TransactionStatus.approved),
  );

  void publish() => events.add(_approved);

  @override
  Stream<List<FinanceTransaction>> watchApprovedTransactions(
    String companyId,
  ) async* {
    if (readFailure != null) throw readFailure!;
    yield _approved;
    yield* events.stream;
  }

  Future<void> dispose() => events.close();
}
