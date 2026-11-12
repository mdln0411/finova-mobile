import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/chart_account.dart';
import '../domain/chart_of_accounts_repository.dart';
import '../domain/default_chart_of_accounts.dart';
import 'chart_account_codec.dart';

class FirebaseChartOfAccountsRepository implements ChartOfAccountsRepository {
  FirebaseChartOfAccountsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _providedStore = firestore,
       _providedAuth = auth;
  final FirebaseFirestore? _providedStore;
  final FirebaseAuth? _providedAuth;
  FirebaseFirestore get _store => _providedStore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _providedAuth ?? FirebaseAuth.instance;

  void _validateCompany(String companyId) {
    if (companyId.isEmpty ||
        companyId.contains('/') ||
        companyId == '.' ||
        companyId == '..') {
      throw const ChartOfAccountsFailure('Identitas perusahaan tidak valid.');
    }
    if (_auth.currentUser == null) {
      throw const ChartOfAccountsFailure(
        'Sesi berakhir. Silakan masuk kembali.',
      );
    }
  }

  ChartOfAccountsFailure _failure(Object error) {
    if (error is ChartOfAccountsFailure) return error;
    if (error is FirebaseException) {
      developer.log(
        'chart_of_accounts code=${error.code}',
        name: 'finova.accounts',
      );
      if (error.code == 'permission-denied') {
        return const ChartOfAccountsFailure(
          'Akses kategori akun ditolak. Periksa membership dan penerapan Firestore Rules bersama pengelola.',
        );
      }
    }
    return const ChartOfAccountsFailure(
      'Kategori akun belum dapat diakses. Periksa koneksi dan coba lagi.',
    );
  }

  @override
  Stream<List<ChartAccount>> watchAccounts(String companyId) {
    try {
      _validateCompany(companyId);
      final query = _store
          .collection('companies')
          .doc(companyId)
          .collection('chart_of_accounts')
          .orderBy('code');
      // Transformasi stream meneruskan cancel langsung ke listener Firestore,
      // termasuk ketika tidak ada event baru setelah keluar halaman/logout.
      return query
          .snapshots(includeMetadataChanges: true)
          .where(
            (snapshot) =>
                !snapshot.metadata.isFromCache &&
                !snapshot.metadata.hasPendingWrites,
          )
          .map((snapshot) {
            final accounts = snapshot.docs
                .map(
                  (doc) => ChartAccountCodec.fromDocument(doc.id, doc.data()),
                )
                .toList();
            ChartAccount.validateChart(accounts);
            return List<ChartAccount>.unmodifiable(accounts);
          })
          .transform(
            StreamTransformer<
              List<ChartAccount>,
              List<ChartAccount>
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
  Future<int> initializeDefaults(String companyId) async {
    try {
      _validateCompany(companyId);
      final uid = _auth.currentUser!.uid;
      final companyRef = _store.collection('companies').doc(companyId);
      return await _store
          .runTransaction((transaction) async {
            // UX juga memeriksa server. Otorisasi sesungguhnya tetap di Rules.
            final profile = (await transaction.get(
              _store.collection('users').doc(uid),
            )).data();
            final access = (await transaction.get(
              _store.collection('company_access').doc(uid),
            )).data();
            final company = (await transaction.get(companyRef)).data();
            final member = (await transaction.get(
              companyRef.collection('members').doc(uid),
            )).data();
            if (profile?['uid'] != uid ||
                profile?['profileCompleted'] != true ||
                access?['uid'] != uid ||
                access?['companyId'] != companyId ||
                company?['status'] != 'active' ||
                member?['uid'] != uid ||
                member?['status'] != 'active' ||
                member?['role'] != 'manager') {
              throw const ChartOfAccountsFailure(
                'Hanya Manager dengan membership aktif yang dapat menyiapkan kategori default.',
              );
            }
            final missing = <ChartAccount>[];
            for (final template in defaultChartOfAccounts) {
              final snapshot = await transaction.get(
                companyRef.collection('chart_of_accounts').doc(template.code),
              );
              final data = snapshot.data();
              if (data == null) {
                missing.add(template);
              } else {
                final existing = ChartAccountCodec.fromDocument(
                  template.code,
                  data,
                );
                if (existing.type != template.type ||
                    existing.normalBalance != template.normalBalance ||
                    existing.parentCode != template.parentCode ||
                    existing.isPosting != template.isPosting) {
                  throw const ChartOfAccountsFailure(
                    'Kode akun default sudah digunakan dengan struktur berbeda. Hubungi Manager.',
                  );
                }
              }
            }
            // Seluruh read selesai sebelum write. Retry transaksi memakai ID sama.
            for (final account in missing) {
              transaction.set(
                companyRef.collection('chart_of_accounts').doc(account.code),
                {
                  ...ChartAccountCodec.values(account),
                  'createdBy': uid,
                  'createdAt': FieldValue.serverTimestamp(),
                  'updatedAt': FieldValue.serverTimestamp(),
                },
              );
            }
            return missing.length;
          })
          .timeout(const Duration(seconds: 25));
    } catch (error) {
      throw _failure(error);
    }
  }
}
