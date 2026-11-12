import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../transactions/data/transaction_codec.dart';
import '../../transactions/domain/finance_transaction.dart';
import '../domain/bill.dart';
import '../domain/receivable.dart';
import '../domain/receivables_repository.dart';
import 'receivable_codec.dart';

class FirebaseReceivablesRepository implements ReceivablesRepository {
  FirebaseReceivablesRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _providedStore = firestore,
       _providedAuth = auth;

  final FirebaseFirestore? _providedStore;
  final FirebaseAuth? _providedAuth;
  FirebaseFirestore get _store => _providedStore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _providedAuth ?? FirebaseAuth.instance;
  static const _timeout = Duration(seconds: 25);

  String _uid(String companyId) {
    if (companyId.isEmpty ||
        companyId.contains('/') ||
        companyId == '.' ||
        companyId == '..') {
      throw const ReceivableFailure('Identitas perusahaan tidak valid.');
    }
    final user = _auth.currentUser;
    if (user == null) {
      throw const ReceivableFailure('Sesi berakhir. Silakan masuk kembali.');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> _collection(String companyId) =>
      _store.collection('companies').doc(companyId).collection('receivables');

  DocumentReference<Map<String, dynamic>> _doc(String companyId, String id) {
    if (id.isEmpty || id.contains('/') || id == '.' || id == '..') {
      throw const ReceivableFailure('Identitas piutang tidak valid.');
    }
    return _collection(companyId).doc(id);
  }

  DocumentReference<Map<String, dynamic>> _recognitionDoc(
    String companyId,
    String receivableId,
  ) => _store
      .collection('companies')
      .doc(companyId)
      .collection('transactions')
      .doc('receivable-$receivableId');

  ReceivableFailure _failure(Object error) {
    if (error is ReceivableFailure) return error;
    if (error is TimeoutException) {
      return const ReceivableFailure(
        'Server belum merespons. Periksa koneksi lalu coba lagi.',
      );
    }
    if (error is FirebaseException) {
      developer.log(
        'receivables code=${error.code}',
        name: 'finova.receivables',
      );
      if (error.code == 'permission-denied') {
        return const ReceivableFailure(
          'Akses ditolak. Piutang mungkin sudah diproses atau Anda tidak berwenang.',
        );
      }
      if (error.code == 'not-found') {
        return const ReceivableFailure('Piutang tidak ditemukan.');
      }
    }
    return const ReceivableFailure(
      'Piutang belum dapat diproses. Periksa koneksi dan coba lagi.',
    );
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action().timeout(_timeout);
    } catch (error) {
      throw _failure(error);
    }
  }

  @override
  Stream<List<Receivable>> watchReceivables(String companyId) {
    try {
      _uid(companyId);
      return _collection(companyId)
          .snapshots(includeMetadataChanges: true)
          .where(
            (snapshot) =>
                !snapshot.metadata.isFromCache &&
                !snapshot.metadata.hasPendingWrites,
          )
          .map((snapshot) {
            final items =
                snapshot.docs
                    .map(
                      (document) => ReceivableCodec.fromDocument(
                        document.id,
                        document.data(),
                      ),
                    )
                    .toList()
                  ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
            return List<Receivable>.unmodifiable(items);
          })
          .transform(
            StreamTransformer<List<Receivable>, List<Receivable>>.fromHandlers(
              handleError: (error, stack, sink) =>
                  sink.addError(_failure(error), stack),
            ),
          );
    } catch (error) {
      return Stream.error(_failure(error));
    }
  }

  @override
  Stream<List<Bill>> watchBills(String companyId) {
    try {
      _uid(companyId);
      return _store
          .collection('companies')
          .doc(companyId)
          .collection('transactions')
          .snapshots(includeMetadataChanges: true)
          .where(
            (snapshot) =>
                !snapshot.metadata.isFromCache &&
                !snapshot.metadata.hasPendingWrites,
          )
          .map((snapshot) {
            final bills =
                snapshot.docs
                    .where((document) {
                      final receivableId = document.data()['receivableId'];
                      return receivableId is String &&
                          receivableId.isNotEmpty &&
                          document.data()['categoryAccountId'] == '1300';
                    })
                    .map((document) {
                      final transaction = TransactionCodec.fromDocument(
                        document.id,
                        document.data(),
                      );
                      if (transaction.type != TransactionType.income) {
                        throw const ReceivableFailure(
                          'Riwayat pembayaran piutang tidak sesuai.',
                        );
                      }
                      return Bill.fromTransaction(transaction);
                    })
                    .toList()
                  ..sort((a, b) => b.date.compareTo(a.date));
            return List<Bill>.unmodifiable(bills);
          })
          .transform(
            StreamTransformer<List<Bill>, List<Bill>>.fromHandlers(
              handleError: (error, stack, sink) =>
                  sink.addError(_failure(error), stack),
            ),
          );
    } catch (error) {
      return Stream.error(_failure(error));
    }
  }

  @override
  String newReceivableId(String companyId) => _collection(companyId).doc().id;

  @override
  Future<void> create(String companyId, String id, ReceivableDraft draft) =>
      _guard(() async {
        final uid = _uid(companyId);
        final reference = _doc(companyId, id);
        await _store.runTransaction((transaction) async {
          final existing = await transaction.get(reference);
          if (existing.exists) {
            if (existing.data()?['createdBy'] == uid) return;
            throw const ReceivableFailure('ID piutang sudah digunakan.');
          }
          transaction.set(reference, {
            ...ReceivableCodec.draftValues(draft),
            'status': ReceivableStatus.pending.name,
            'createdBy': uid,
            'createdAt': FieldValue.serverTimestamp(),
            'approvedBy': null,
            'approvedAt': null,
            'rejectReason': null,
          });
        });
      });

  @override
  Future<void> update(String companyId, String id, ReceivableDraft draft) =>
      _guard(() async {
        _uid(companyId);
        await _doc(companyId, id).update(ReceivableCodec.draftValues(draft));
      });

  @override
  Future<void> delete(String companyId, String id) => _guard(() async {
    _uid(companyId);
    await _doc(companyId, id).delete();
  });

  @override
  Future<void> approve(String companyId, String id) => _guard(() async {
    final uid = _uid(companyId);
    final receivableReference = _doc(companyId, id);
    final recognitionReference = _recognitionDoc(companyId, id);
    await _store.runTransaction((transaction) async {
      final receivableSnapshot = await transaction.get(receivableReference);
      final recognitionSnapshot = await transaction.get(recognitionReference);
      final data = receivableSnapshot.data();
      if (data == null) {
        throw const ReceivableFailure('Piutang tidak ditemukan.');
      }
      if (data['status'] == ReceivableStatus.approved.name) {
        final recognition = recognitionSnapshot.data();
        if (recognition?['receivableId'] == id &&
            recognition?['status'] == TransactionStatus.approved.name &&
            recognition?['amount'] == data['amount'] &&
            recognition?['cashAccountId'] == '1300' &&
            recognition?['categoryAccountId'] == data['revenueAccountId'] &&
            recognition?['approvedBy'] == data['approvedBy']) {
          return;
        }
        throw const ReceivableFailure(
          'Jurnal pengakuan piutang tidak ditemukan. Hubungi Manager.',
        );
      }
      if (data['status'] != ReceivableStatus.pending.name) {
        throw const ReceivableFailure(
          'Piutang sudah diproses atau tidak dapat disetujui.',
        );
      }
      if (recognitionSnapshot.exists) {
        throw const ReceivableFailure(
          'ID jurnal piutang sudah digunakan. Hubungi Manager.',
        );
      }
      final receivable = ReceivableCodec.fromDocument(id, data);
      final timestamp = FieldValue.serverTimestamp();
      transaction.update(receivableReference, {
        'status': ReceivableStatus.approved.name,
        'approvedBy': uid,
        'approvedAt': timestamp,
        'rejectReason': null,
      });
      transaction.set(recognitionReference, {
        'type': TransactionType.income.name,
        'amount': receivable.amount,
        'date': FieldValue.serverTimestamp(),
        'description':
            'Pengakuan piutang ${receivable.number} · ${receivable.customerName}',
        'cashAccountId': '1300',
        'categoryAccountId': receivable.revenueAccountId,
        'receivableId': receivable.id,
        'status': TransactionStatus.approved.name,
        'createdBy': uid,
        'createdAt': timestamp,
        'approvedBy': uid,
        'approvedAt': timestamp,
        'rejectReason': null,
      });
    });
  });

  @override
  Future<void> reject(String companyId, String id, String reason) =>
      _guard(() async {
        final uid = _uid(companyId);
        final error = validateRejectReason(reason);
        if (error != null) throw ReceivableFailure(error);
        await _doc(companyId, id).update({
          'status': ReceivableStatus.rejected.name,
          'approvedBy': uid,
          'approvedAt': FieldValue.serverTimestamp(),
          'rejectReason': reason.trim(),
        });
      });
}
