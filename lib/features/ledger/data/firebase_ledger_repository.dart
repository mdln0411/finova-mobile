import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../transactions/data/transaction_codec.dart';
import '../../transactions/domain/finance_transaction.dart';
import '../domain/ledger_repository.dart';

/// Query `status == approved` + `orderBy(date)` memakai composite index
/// pada `firestore.indexes.json`.
class FirebaseLedgerRepository implements LedgerRepository {
  FirebaseLedgerRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _providedStore = firestore,
      _providedAuth = auth;
  final FirebaseFirestore? _providedStore;
  final FirebaseAuth? _providedAuth;
  FirebaseFirestore get _store => _providedStore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _providedAuth ?? FirebaseAuth.instance;

  TransactionFailure _failure(Object error) {
    if (error is TransactionFailure) return error;
    if (error is FirebaseException) {
      developer.log('ledger code=${error.code}', name: 'finova.ledger');
      if (error.code == 'permission-denied') {
        return const TransactionFailure('Akses buku besar ditolak.');
      }
    }
    return const TransactionFailure(
      'Buku besar belum dapat dimuat. Periksa koneksi dan coba lagi.',
    );
  }

  @override
  Stream<List<FinanceTransaction>> watchApprovedTransactions(String companyId) {
    if (companyId.isEmpty ||
        companyId.contains('/') ||
        companyId == '.' ||
        companyId == '..') {
      return Stream.error(
        const TransactionFailure('Identitas perusahaan tidak valid.'),
      );
    }
    if (_auth.currentUser == null) {
      return Stream.error(
        const TransactionFailure('Sesi berakhir. Silakan masuk kembali.'),
      );
    }
    return _store
        .collection('companies')
        .doc(companyId)
        .collection('transactions')
        .where('status', isEqualTo: TransactionStatus.approved.name)
        .orderBy('date', descending: true)
        .snapshots(includeMetadataChanges: true)
        // Samakan dengan daftar transaksi: tunggu data terkonfirmasi server.
        .where(
          (snapshot) =>
              !snapshot.metadata.isFromCache &&
              !snapshot.metadata.hasPendingWrites,
        )
        .map(
          (snapshot) => List<FinanceTransaction>.unmodifiable(
            snapshot.docs.map(
              (d) => TransactionCodec.fromDocument(d.id, d.data()),
            ),
          ),
        )
        .transform(
          StreamTransformer<
            List<FinanceTransaction>,
            List<FinanceTransaction>
          >.fromHandlers(
            handleError: (error, stack, sink) =>
                sink.addError(_failure(error), stack),
          ),
        );
  }
}
