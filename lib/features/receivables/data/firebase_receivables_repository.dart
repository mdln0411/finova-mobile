import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../transactions/data/transaction_codec.dart';
import '../../transactions/domain/finance_transaction.dart';
import '../domain/receivable.dart';
import '../domain/receivable_status.dart';
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
  Stream<List<FinanceTransaction>> watchPayments(String companyId) {
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
            final payments =
                snapshot.docs
                    .where((document) {
                      final receivableId = document.data()['receivableId'];
                      return receivableId is String && receivableId.isNotEmpty;
                    })
                    .map(
                      (document) => TransactionCodec.fromDocument(
                        document.id,
                        document.data(),
                      ),
                    )
                    .toList()
                  ..sort((a, b) => b.date.compareTo(a.date));
            return List<FinanceTransaction>.unmodifiable(payments);
          })
          .transform(
            StreamTransformer<
              List<FinanceTransaction>,
              List<FinanceTransaction>
            >.fromHandlers(
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
  Future<void> create(String companyId, Receivable receivable) =>
      _guard(() async {
        final uid = _uid(companyId);
        final reference = _doc(companyId, receivable.id);
        await _store.runTransaction((transaction) async {
          final existing = await transaction.get(reference);
          if (existing.exists) {
            if (existing.data()?['createdBy'] == uid) return;
            throw const ReceivableFailure('ID piutang sudah digunakan.');
          }
          transaction.set(reference, {
            ...ReceivableCodec.draftValues(receivable),
            'status': TransactionStatus.pending.name,
            'createdBy': uid,
            'createdAt': FieldValue.serverTimestamp(),
            'approvedBy': null,
            'approvedAt': null,
            'rejectReason': null,
          });
        });
      });

  @override
  Future<void> update(String companyId, Receivable receivable) =>
      _guard(() async {
        _uid(companyId);
        await _doc(
          companyId,
          receivable.id,
        ).update(ReceivableCodec.draftValues(receivable));
      });

  @override
  Future<void> delete(String companyId, String id) => _guard(() async {
    _uid(companyId);
    await _doc(companyId, id).delete();
  });

  /// Hanya status yang berubah. Jurnal Piutang/Pendapatan dihitung
  /// [LedgerCalculator] langsung dari piutang approved, sehingga tidak ada
  /// transaksi pengakuan terpisah (mencegah penghitungan ganda).
  @override
  Future<void> approve(String companyId, String id) => _guard(() async {
    final uid = _uid(companyId);
    await _doc(companyId, id).update({
      'status': TransactionStatus.approved.name,
      'approvedBy': uid,
      'approvedAt': FieldValue.serverTimestamp(),
      'rejectReason': null,
    });
  });

  @override
  Future<void> reject(String companyId, String id, String reason) =>
      _guard(() async {
        final uid = _uid(companyId);
        final error = validateRejectReason(reason);
        if (error != null) throw ReceivableFailure(error);
        await _doc(companyId, id).update({
          'status': TransactionStatus.rejected.name,
          'approvedBy': uid,
          'approvedAt': FieldValue.serverTimestamp(),
          'rejectReason': reason.trim(),
        });
      });
}
