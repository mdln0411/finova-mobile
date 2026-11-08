import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/finance_transaction.dart';
import '../domain/transactions_repository.dart';
import 'transaction_codec.dart';

class FirebaseTransactionsRepository implements TransactionsRepository {
  FirebaseTransactionsRepository({
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
      throw const TransactionFailure('Identitas perusahaan tidak valid.');
    }
    final user = _auth.currentUser;
    if (user == null) {
      throw const TransactionFailure('Sesi berakhir. Silakan masuk kembali.');
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> _collection(String companyId) =>
      _store.collection('companies').doc(companyId).collection('transactions');

  DocumentReference<Map<String, dynamic>> _doc(String companyId, String id) {
    if (id.isEmpty || id.contains('/') || id == '.' || id == '..') {
      throw const TransactionFailure('Identitas transaksi tidak valid.');
    }
    return _collection(companyId).doc(id);
  }

  TransactionFailure _failure(Object error) {
    if (error is TransactionFailure) return error;
    if (error is TimeoutException) {
      return const TransactionFailure(
        'Server belum merespons. Periksa koneksi lalu coba lagi.',
      );
    }
    if (error is FirebaseException) {
      developer.log('transactions code=${error.code}', name: 'finova.tx');
      if (error.code == 'permission-denied') {
        return const TransactionFailure(
          'Akses ditolak. Transaksi mungkin sudah diproses atau Anda tidak berwenang.',
        );
      }
      if (error.code == 'not-found') {
        return const TransactionFailure('Transaksi tidak ditemukan.');
      }
    }
    return const TransactionFailure(
      'Transaksi belum dapat diproses. Periksa koneksi dan coba lagi.',
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
  Stream<List<FinanceTransaction>> watchTransactions(String companyId) {
    try {
      _uid(companyId);
      return _collection(companyId)
          .orderBy('date', descending: true)
          .snapshots(includeMetadataChanges: true)
          // serverTimestamp masih null pada snapshot lokal; tunggu konfirmasi.
          .where(
            (snapshot) =>
                !snapshot.metadata.isFromCache &&
                !snapshot.metadata.hasPendingWrites,
          )
          .map((snapshot) {
            final items = snapshot.docs
                .map((d) => TransactionCodec.fromDocument(d.id, d.data()))
                .toList();
            sortTransactions(items);
            return List<FinanceTransaction>.unmodifiable(items);
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
  String newTransactionId(String companyId) => _collection(companyId).doc().id;

  @override
  Future<void> create(String companyId, String id, TransactionDraft draft) =>
      _guard(() async {
        final uid = _uid(companyId);
        final ref = _doc(companyId, id);
        await _store.runTransaction((transaction) async {
          final existing = await transaction.get(ref);
          // Retry setelah commit sebelumnya berhasil: jangan tulis ulang.
          if (existing.exists) {
            if (existing.data()?['createdBy'] == uid) return;
            throw const TransactionFailure('ID transaksi sudah digunakan.');
          }
          transaction.set(ref, {
            ...TransactionCodec.draftValues(draft),
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
  Future<void> update(String companyId, String id, TransactionDraft draft) =>
      _guard(() async {
        _uid(companyId);
        await _doc(companyId, id).update(TransactionCodec.draftValues(draft));
      });

  @override
  Future<void> delete(String companyId, String id) => _guard(() async {
    _uid(companyId);
    await _doc(companyId, id).delete();
  });

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
        if (error != null) throw TransactionFailure(error);
        await _doc(companyId, id).update({
          'status': TransactionStatus.rejected.name,
          'approvedBy': uid,
          'approvedAt': FieldValue.serverTimestamp(),
          'rejectReason': reason.trim(),
        });
      });
}
