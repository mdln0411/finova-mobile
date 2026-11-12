import 'dart:async';

import 'package:finova/features/transactions/domain/finance_transaction.dart';
import 'package:finova/features/transactions/domain/transactions_repository.dart';

/// Meniru aturan Rules secara sederhana: status awal pending dan
/// transaksi yang sudah diputuskan tidak dapat diubah.
class FakeTransactionsRepository implements TransactionsRepository {
  FakeTransactionsRepository({this.uid = 'test-user'});
  final String uid;
  List<FinanceTransaction> items = [];
  TransactionFailure? readFailure;
  TransactionFailure? writeFailure;
  final calls = <String>[];
  int _seq = 0;
  final events = StreamController<List<FinanceTransaction>>.broadcast();

  void _publish() {
    sortTransactions(items);
    events.add(List.unmodifiable(items));
  }

  FinanceTransaction _pending(String id) {
    final tx = items.where((tx) => tx.id == id).firstOrNull;
    if (tx == null || !tx.isPending) {
      throw const TransactionFailure('Akses ditolak.');
    }
    return tx;
  }

  FinanceTransaction _copy(
    FinanceTransaction tx, {
    TransactionDraft? draft,
    TransactionStatus? status,
    String? reason,
  }) => FinanceTransaction(
    id: tx.id,
    type: draft?.type ?? tx.type,
    amount: draft?.amount ?? tx.amount,
    date: draft?.date ?? tx.date,
    description: draft?.description.trim() ?? tx.description,
    cashAccountId: draft?.cashAccountId ?? tx.cashAccountId,
    categoryAccountId: draft?.categoryAccountId ?? tx.categoryAccountId,
    status: status ?? tx.status,
    createdBy: tx.createdBy,
    createdAt: tx.createdAt,
    receivableId: tx.receivableId,
    approvedBy: status == null ? tx.approvedBy : uid,
    approvedAt: status == null ? tx.approvedAt : DateTime.now(),
    rejectReason: reason ?? tx.rejectReason,
  );

  void _replace(FinanceTransaction tx) {
    items = [for (final item in items) item.id == tx.id ? tx : item];
  }

  @override
  Stream<List<FinanceTransaction>> watchTransactions(String companyId) async* {
    if (readFailure != null) throw readFailure!;
    yield List.unmodifiable(items);
    yield* events.stream;
  }

  @override
  String newTransactionId(String companyId) => 'tx-${++_seq}';

  @override
  Future<void> create(
    String companyId,
    String id,
    TransactionDraft draft,
  ) async {
    calls.add('create:$id');
    if (writeFailure != null) throw writeFailure!;
    if (items.any((tx) => tx.id == id)) return;
    items = [
      ...items,
      FinanceTransaction(
        id: id,
        type: draft.type,
        amount: draft.amount,
        date: dateOnly(draft.date),
        description: draft.description.trim(),
        cashAccountId: draft.cashAccountId,
        categoryAccountId: draft.categoryAccountId,
        status: TransactionStatus.pending,
        createdBy: uid,
        createdAt: DateTime.now(),
        receivableId: draft.receivableId,
      ),
    ];
    _publish();
  }

  @override
  Future<void> update(
    String companyId,
    String id,
    TransactionDraft draft,
  ) async {
    calls.add('update:$id');
    if (writeFailure != null) throw writeFailure!;
    _replace(_copy(_pending(id), draft: draft));
    _publish();
  }

  @override
  Future<void> delete(String companyId, String id) async {
    calls.add('delete:$id');
    if (writeFailure != null) throw writeFailure!;
    _pending(id);
    items = items.where((tx) => tx.id != id).toList();
    _publish();
  }

  @override
  Future<void> approve(String companyId, String id) async {
    calls.add('approve:$id');
    if (writeFailure != null) throw writeFailure!;
    _replace(_copy(_pending(id), status: TransactionStatus.approved));
    _publish();
  }

  @override
  Future<void> reject(String companyId, String id, String reason) async {
    calls.add('reject:$id:$reason');
    if (writeFailure != null) throw writeFailure!;
    _replace(
      _copy(_pending(id), status: TransactionStatus.rejected, reason: reason),
    );
    _publish();
  }

  Future<void> dispose() => events.close();
}

FinanceTransaction sampleTransaction({
  String id = 'tx-a',
  String createdBy = 'test-user',
  TransactionStatus status = TransactionStatus.pending,
  TransactionType type = TransactionType.expense,
  String description = 'Beli ATK kantor',
  int amount = 150000,
}) => FinanceTransaction(
  id: id,
  type: type,
  amount: amount,
  date: DateTime.utc(2026, 3, 2),
  description: description,
  cashAccountId: '1100',
  categoryAccountId: type == TransactionType.income ? '4100' : '5900',
  status: status,
  createdBy: createdBy,
  createdAt: DateTime.utc(2026, 3, 2, 8),
);
