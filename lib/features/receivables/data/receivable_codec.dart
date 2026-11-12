import 'package:cloud_firestore/cloud_firestore.dart';

import '../../transactions/domain/finance_transaction.dart';
import '../domain/receivable.dart';

abstract final class ReceivableCodec {
  static Map<String, dynamic> draftValues(ReceivableDraft draft) => {
    'customerName': draft.customerName.trim(),
    'number': draft.number.trim(),
    'amount': draft.amount,
    'revenueAccountId': draft.revenueAccountId,
    'dueDate': Timestamp.fromDate(dateOnly(draft.dueDate)),
    'description': draft.description.trim(),
  };

  static Receivable fromDocument(String id, Map<String, dynamic> data) {
    final status = ReceivableStatus.values
        .where((value) => value.name == data['status'])
        .firstOrNull;
    final amount = data['amount'];
    final dueDate = data['dueDate'];
    final createdAt = data['createdAt'];
    final approvedAt = data['approvedAt'];
    final approvedBy = data['approvedBy'];
    final rejectReason = data['rejectReason'];
    if (status == null ||
        data['customerName'] is! String ||
        data['number'] is! String ||
        amount is! int ||
        amount <= 0 ||
        data['revenueAccountId'] is! String ||
        dueDate is! Timestamp ||
        data['description'] is! String ||
        data['createdBy'] is! String ||
        createdAt is! Timestamp ||
        (approvedAt != null && approvedAt is! Timestamp) ||
        (approvedBy != null && approvedBy is! String) ||
        (rejectReason != null && rejectReason is! String)) {
      throw const ReceivableFailure(
        'Format piutang belum sesuai. Hubungi Manager untuk memeriksa data.',
      );
    }
    return Receivable(
      id: id,
      customerName: data['customerName'] as String,
      number: data['number'] as String,
      amount: amount,
      revenueAccountId: data['revenueAccountId'] as String,
      dueDate: dueDate.toDate().toUtc(),
      description: data['description'] as String,
      status: status,
      createdBy: data['createdBy'] as String,
      createdAt: createdAt.toDate(),
      approvedBy: approvedBy as String?,
      approvedAt: (approvedAt as Timestamp?)?.toDate(),
      rejectReason: rejectReason as String?,
    );
  }
}
