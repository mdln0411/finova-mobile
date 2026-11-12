import 'dart:async';

import 'package:finova/features/receivables/domain/bill.dart';
import 'package:finova/features/receivables/domain/receivable.dart';
import 'package:finova/features/receivables/domain/receivables_repository.dart';
import 'package:finova/features/transactions/domain/finance_transaction.dart';

class FakeReceivablesRepository implements ReceivablesRepository {
  FakeReceivablesRepository({this.uid = 'test-user'});

  final String uid;
  List<Receivable> items = [];
  List<Bill> bills = [];
  final calls = <String>[];
  int _seq = 0;
  final _receivableEvents = StreamController<List<Receivable>>.broadcast();
  final _billEvents = StreamController<List<Bill>>.broadcast();

  void _publishReceivables() {
    items.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    _receivableEvents.add(List.unmodifiable(items));
  }

  void publishBills(List<Bill> value) {
    bills = value;
    _billEvents.add(List.unmodifiable(bills));
  }

  void _replace(Receivable value) {
    items = [for (final item in items) item.id == value.id ? value : item];
  }

  @override
  Stream<List<Receivable>> watchReceivables(String companyId) async* {
    yield List.unmodifiable(items);
    yield* _receivableEvents.stream;
  }

  @override
  Stream<List<Bill>> watchBills(String companyId) async* {
    yield List.unmodifiable(bills);
    yield* _billEvents.stream;
  }

  @override
  String newReceivableId(String companyId) => 'receivable-${++_seq}';

  @override
  Future<void> create(
    String companyId,
    String id,
    ReceivableDraft draft,
  ) async {
    calls.add('create:$id');
    if (items.any((item) => item.id == id)) return;
    items = [
      ...items,
      Receivable(
        id: id,
        customerName: draft.customerName.trim(),
        number: draft.number.trim(),
        amount: draft.amount,
        revenueAccountId: draft.revenueAccountId,
        dueDate: dateOnly(draft.dueDate),
        description: draft.description.trim(),
        status: ReceivableStatus.pending,
        createdBy: uid,
        createdAt: DateTime.now(),
      ),
    ];
    _publishReceivables();
  }

  @override
  Future<void> update(
    String companyId,
    String id,
    ReceivableDraft draft,
  ) async {
    calls.add('update:$id');
    final old = items.firstWhere((item) => item.id == id);
    _replace(
      Receivable(
        id: old.id,
        customerName: draft.customerName.trim(),
        number: draft.number.trim(),
        amount: draft.amount,
        revenueAccountId: draft.revenueAccountId,
        dueDate: dateOnly(draft.dueDate),
        description: draft.description.trim(),
        status: old.status,
        createdBy: old.createdBy,
        createdAt: old.createdAt,
        approvedBy: old.approvedBy,
        approvedAt: old.approvedAt,
        rejectReason: old.rejectReason,
      ),
    );
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
    _replace(
      Receivable(
        id: old.id,
        customerName: old.customerName,
        number: old.number,
        amount: old.amount,
        revenueAccountId: old.revenueAccountId,
        dueDate: old.dueDate,
        description: old.description,
        status: ReceivableStatus.approved,
        createdBy: old.createdBy,
        createdAt: old.createdAt,
        approvedBy: uid,
        approvedAt: DateTime.now(),
      ),
    );
    _publishReceivables();
  }

  @override
  Future<void> reject(String companyId, String id, String reason) async {
    calls.add('reject:$id:$reason');
    final old = items.firstWhere((item) => item.id == id);
    _replace(
      Receivable(
        id: old.id,
        customerName: old.customerName,
        number: old.number,
        amount: old.amount,
        revenueAccountId: old.revenueAccountId,
        dueDate: old.dueDate,
        description: old.description,
        status: ReceivableStatus.rejected,
        createdBy: old.createdBy,
        createdAt: old.createdAt,
        approvedBy: uid,
        approvedAt: DateTime.now(),
        rejectReason: reason,
      ),
    );
    _publishReceivables();
  }

  Future<void> dispose() async {
    await _receivableEvents.close();
    await _billEvents.close();
  }
}

Receivable sampleReceivable({
  String id = 'r1',
  String createdBy = 'test-user',
  ReceivableStatus status = ReceivableStatus.pending,
  DateTime? dueDate,
  int amount = 150000,
}) => Receivable(
  id: id,
  customerName: 'Customer Finova',
  number: 'INV-001',
  amount: amount,
  revenueAccountId: '4100',
  dueDate: dueDate ?? DateTime.utc(2026, 3, 10),
  description: 'Penjualan barang',
  status: status,
  createdBy: createdBy,
  createdAt: DateTime.utc(2026, 3, 1),
);
