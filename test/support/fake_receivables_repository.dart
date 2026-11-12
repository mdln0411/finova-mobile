import 'dart:async';

import 'package:finova/features/receivables/domain/receivable.dart';
import 'package:finova/features/receivables/domain/receivables_repository.dart';
import 'package:finova/features/transactions/domain/finance_transaction.dart';

class FakeReceivablesRepository implements ReceivablesRepository {
  FakeReceivablesRepository({this.uid = 'test-user'});

  final String uid;
  List<Receivable> items = [];
  List<FinanceTransaction> payments = [];
  final calls = <String>[];
  int _seq = 0;
  final _receivableEvents = StreamController<List<Receivable>>.broadcast();
  final _paymentEvents = StreamController<List<FinanceTransaction>>.broadcast();

  void _publishReceivables() {
    items.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    _receivableEvents.add(List.unmodifiable(items));
  }

  void publishPayments(List<FinanceTransaction> value) {
    payments = value;
    _paymentEvents.add(List.unmodifiable(payments));
  }

  void _replace(Receivable value) {
    items = [for (final item in items) item.id == value.id ? value : item];
  }

  Receivable _copy(
    Receivable old, {
    Receivable? fields,
    TransactionStatus? status,
    String? reason,
  }) {
    final source = fields ?? old;
    return Receivable(
      id: old.id,
      customerName: source.customerName.trim(),
      number: source.number.trim(),
      amount: source.amount,
      issueDate: dateOnly(source.issueDate),
      dueDate: dateOnly(source.dueDate),
      description: source.description.trim(),
      revenueAccountId: source.revenueAccountId,
      status: status ?? old.status,
      createdBy: old.createdBy,
      createdAt: old.createdAt,
      approvedBy: status == null ? old.approvedBy : uid,
      approvedAt: status == null ? old.approvedAt : DateTime.now(),
      rejectReason: status == null ? old.rejectReason : reason,
    );
  }

  @override
  Stream<List<Receivable>> watchReceivables(String companyId) async* {
    yield List.unmodifiable(items);
    yield* _receivableEvents.stream;
  }

  @override
  Stream<List<FinanceTransaction>> watchPayments(String companyId) async* {
    yield List.unmodifiable(payments);
    yield* _paymentEvents.stream;
  }

  @override
  String newReceivableId(String companyId) => 'receivable-${++_seq}';

  @override
  Future<void> create(String companyId, Receivable receivable) async {
    calls.add('create:${receivable.id}');
    if (items.any((item) => item.id == receivable.id)) return;
    final created = Receivable(
      id: receivable.id,
      customerName: receivable.customerName,
      number: receivable.number,
      amount: receivable.amount,
      issueDate: receivable.issueDate,
      dueDate: receivable.dueDate,
      description: receivable.description,
      revenueAccountId: receivable.revenueAccountId,
      status: TransactionStatus.pending,
      createdBy: uid,
      createdAt: DateTime.now(),
    );
    items = [...items, _copy(created)];
    _publishReceivables();
  }

  @override
  Future<void> update(String companyId, Receivable receivable) async {
    calls.add('update:${receivable.id}');
    final old = items.firstWhere((item) => item.id == receivable.id);
    _replace(_copy(old, fields: receivable));
    _publishReceivables();
  }

  @override
  Future<void> delete(String companyId, String id) async {
    calls.add('delete:$id');
    items = items.where((item) => item.id != id).toList();
    _publishReceivables();
  }

  @override
  Future<void> approve(String companyId, String id) async {
    calls.add('approve:$id');
    final old = items.firstWhere((item) => item.id == id);
    _replace(_copy(old, status: TransactionStatus.approved));
    _publishReceivables();
  }

  @override
  Future<void> reject(String companyId, String id, String reason) async {
    calls.add('reject:$id:$reason');
    final old = items.firstWhere((item) => item.id == id);
    _replace(_copy(old, status: TransactionStatus.rejected, reason: reason));
    _publishReceivables();
  }

  Future<void> dispose() async {
    await _receivableEvents.close();
    await _paymentEvents.close();
  }
}

Receivable sampleReceivable({
  String id = 'r1',
  String createdBy = 'test-user',
  TransactionStatus status = TransactionStatus.pending,
  DateTime? issueDate,
  DateTime? dueDate,
  int amount = 150000,
}) => Receivable(
  id: id,
  customerName: 'Customer Finova',
  number: 'INV-001',
  amount: amount,
  issueDate: issueDate ?? DateTime.utc(2026, 3, 1),
  dueDate: dueDate ?? DateTime.utc(2026, 3, 10),
  description: 'Penjualan barang',
  revenueAccountId: '4100',
  status: status,
  createdBy: createdBy,
  createdAt: DateTime.utc(2026, 3, 1),
);
