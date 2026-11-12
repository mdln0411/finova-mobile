import 'package:cloud_firestore/cloud_firestore.dart';

import '../../transactions/domain/finance_transaction.dart';
import '../domain/receivable.dart';
import '../domain/receivable_status.dart';

abstract final class ReceivableCodec {
  /// Field yang dapat diisi/diedit pembuat selama `pending`.
  static Map<String, dynamic> draftValues(Receivable receivable) => {
    'customerName': receivable.customerName.trim(),
    'number': receivable.number.trim(),
    'amount': receivable.amount,
    'revenueAccountId': receivable.revenueAccountId,
    'issueDate': Timestamp.fromDate(dateOnly(receivable.issueDate)),
    'dueDate': Timestamp.fromDate(dateOnly(receivable.dueDate)),
    'description': receivable.description.trim(),
  };

  static Receivable fromDocument(String id, Map<String, dynamic> data) {
    final status = TransactionStatus.values
        .where((value) => value.name == data['status'])
        .firstOrNull;
    final amount = data['amount'];
    final issueDate = data['issueDate'];
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
        issueDate is! Timestamp ||
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
      issueDate: issueDate.toDate().toUtc(),
      dueDate: dueDate.toDate().toUtc(),
      description: data['description'] as String,
      revenueAccountId: data['revenueAccountId'] as String,
      status: status,
      createdBy: data['createdBy'] as String,
      createdAt: createdAt.toDate(),
      approvedBy: approvedBy as String?,
      approvedAt: (approvedAt as Timestamp?)?.toDate(),
      rejectReason: rejectReason as String?,
    );
  }
}
