import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/finance_transaction.dart';

abstract final class TransactionCodec {
  /// Field yang dapat diedit pembuat selama `pending`.
  static Map<String, dynamic> draftValues(TransactionDraft draft) => {
    'type': draft.type.name,
    'amount': draft.amount,
    'date': Timestamp.fromDate(dateOnly(draft.date)),
    'description': draft.description.trim(),
    'cashAccountId': draft.cashAccountId,
    'categoryAccountId': draft.categoryAccountId,
  };

  static FinanceTransaction fromDocument(String id, Map<String, dynamic> data) {
    final type = TransactionType.values
        .where((value) => value.name == data['type'])
        .firstOrNull;
    final status = TransactionStatus.values
        .where((value) => value.name == data['status'])
        .firstOrNull;
    final amount = data['amount'];
    final date = data['date'];
    final createdAt = data['createdAt'];
    final approvedAt = data['approvedAt'];
    final approvedBy = data['approvedBy'];
    final reason = data['rejectReason'];
    if (type == null ||
        status == null ||
        amount is! int ||
        amount <= 0 ||
        date is! Timestamp ||
        data['description'] is! String ||
        data['cashAccountId'] is! String ||
        data['categoryAccountId'] is! String ||
        data['createdBy'] is! String ||
        createdAt is! Timestamp ||
        (approvedAt != null && approvedAt is! Timestamp) ||
        (approvedBy != null && approvedBy is! String) ||
        (reason != null && reason is! String)) {
      throw const TransactionFailure(
        'Format transaksi belum sesuai. Hubungi Manager untuk memeriksa data.',
      );
    }
    return FinanceTransaction(
      id: id,
      type: type,
      amount: amount,
      date: date.toDate().toUtc(),
      description: data['description'] as String,
      cashAccountId: data['cashAccountId'] as String,
      categoryAccountId: data['categoryAccountId'] as String,
      status: status,
      createdBy: data['createdBy'] as String,
      createdAt: createdAt.toDate(),
      approvedBy: approvedBy as String?,
      approvedAt: (approvedAt as Timestamp?)?.toDate(),
      rejectReason: reason as String?,
    );
  }
}
