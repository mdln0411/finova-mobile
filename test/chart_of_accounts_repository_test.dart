import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finova/features/chart_of_accounts/data/chart_account_codec.dart';
import 'package:finova/features/chart_of_accounts/data/firebase_chart_of_accounts_repository.dart';
import 'package:finova/features/chart_of_accounts/domain/chart_account.dart';
import 'package:finova/features/chart_of_accounts/domain/default_chart_of_accounts.dart';
import 'package:flutter_test/flutter_test.dart';

import 'company_repository_test.dart'
    show CompanyStore, CompanyAuth, CompanyCollection, CompanyRef;
import 'support/fake_auth_repository.dart';

class ChartStore extends CompanyStore {
  ChartStore() {
    documents.addAll({
      'company_access/${testUser.uid}': {
        'uid': testUser.uid,
        'companyId': 'company-1',
      },
      'companies/company-1': {'status': 'active'},
      'companies/company-1/members/${testUser.uid}': {
        'uid': testUser.uid,
        'status': 'active',
        'role': 'manager',
      },
    });
  }
  final snapshots = StreamController<QuerySnapshot<Map<String, dynamic>>>();
  String? queryPath;
  Object? orderField;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      ChartCollection(path, this);
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final result = await super.runTransaction(
      transactionHandler,
      timeout: timeout,
      maxAttempts: maxAttempts,
    );
    // Simulasikan server timestamp sesudah commit, bukan pending write lokal.
    final now = Timestamp.fromDate(DateTime.utc(2026, 11, 4));
    for (final data in documents.values) {
      for (final key in data.keys.toList()) {
        if (data[key] is FieldValue) data[key] = now;
      }
    }
    return result;
  }
}

// ignore: subtype_of_sealed_class
class ChartReference extends CompanyRef {
  ChartReference(super.path, this.store);
  final ChartStore store;
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      ChartCollection('$path/$collectionPath', store);
}

// ignore: subtype_of_sealed_class
class ChartCollection extends CompanyCollection {
  ChartCollection(super.path, this.store);
  final ChartStore store;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      ChartReference('${this.path}/$path', store);
  @override
  Query<Map<String, dynamic>> orderBy(Object field, {bool descending = false}) {
    store.queryPath = path;
    store.orderField = field;
    return ChartQuery(store);
  }
}

// SDK doubles, tidak dipakai aplikasi production.
// ignore: subtype_of_sealed_class
class ChartQuery extends Fake implements Query<Map<String, dynamic>> {
  ChartQuery(this.store);
  final ChartStore store;
  @override
  Stream<QuerySnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => store.snapshots.stream;
}

// ignore: subtype_of_sealed_class
class ChartSnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  ChartSnapshot(this.docs, {this.cached = false, this.pending = false});
  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final bool cached;
  final bool pending;
  @override
  SnapshotMetadata get metadata => ChartMetadata(cached, pending);
}

class ChartMetadata extends Fake implements SnapshotMetadata {
  ChartMetadata(this.isFromCache, this.hasPendingWrites);
  @override
  final bool isFromCache;
  @override
  final bool hasPendingWrites;
}

// ignore: subtype_of_sealed_class
class ChartDocument extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  ChartDocument(this.id, this.value);
  @override
  final String id;
  final Map<String, dynamic> value;
  @override
  Map<String, dynamic> data() => value;
}

void main() {
  test('Repository seed 23 akun atomik, retry idempoten dan akun lama tidak ditimpa', () async {
    final store = ChartStore();
    final repo = FirebaseChartOfAccountsRepository(
      firestore: store,
      auth: CompanyAuth(),
    );
    expect(await repo.initializeDefaults('company-1'), 23);
    expect(store.commitCount, 1);
    final path = 'companies/company-1/chart_of_accounts/4100';
    final account = store.documents[path]!;
    expect(account['createdBy'], testUser.uid);
    expect(account['normalBalance'], 'credit');
    expect(account.containsKey('balance'), isFalse);
    account['name'] = 'Penjualan khusus perusahaan';
    account['isActive'] = false;
    final timestamp = account['createdAt'];
    expect(await repo.initializeDefaults('company-1'), 0);
    expect(store.commitCount, 1);
    expect(store.documents[path], same(account));
    expect(store.documents[path]!['name'], 'Penjualan khusus perusahaan');
    expect(store.documents[path]!['isActive'], isFalse);
    expect(store.documents[path]!['createdAt'], same(timestamp));
  });

  test('Finance/perusahaan lain/profil belum lengkap tidak dapat menyiapkan default', () async {
    for (final restriction in [
      'finance',
      'other-company',
      'incomplete',
      'inactive',
    ]) {
      final store = ChartStore();
      if (restriction == 'finance') {
        store.documents['companies/company-1/members/${testUser.uid}']!['role'] =
            'finance';
      }
      if (restriction == 'other-company') {
        store.documents['company_access/${testUser.uid}']!['companyId'] =
            'other';
      }
      if (restriction == 'incomplete') {
        store.documents['users/${testUser.uid}']!['profileCompleted'] = false;
      }
      if (restriction == 'inactive') {
        store.documents['companies/company-1']!['status'] = 'inactive';
      }
      final repo = FirebaseChartOfAccountsRepository(
        firestore: store,
        auth: CompanyAuth(),
      );
      await expectLater(
        repo.initializeDefaults('company-1'),
        throwsA(isA<ChartOfAccountsFailure>()),
      );
      expect(store.commitCount, 0);
    }
  });

  test('Commit gagal tidak meninggalkan akun parsial dan retry membuat ID yang sama', () async {
    final store = ChartStore()
      ..commitFailure = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
    final repo = FirebaseChartOfAccountsRepository(
      firestore: store,
      auth: CompanyAuth(),
    );
    await expectLater(
      repo.initializeDefaults('company-1'),
      throwsA(isA<ChartOfAccountsFailure>()),
    );
    expect(
      store.documents.keys.where(
        (path) => path.contains('/chart_of_accounts/'),
      ),
      isEmpty,
    );
    store.commitFailure = null;
    expect(await repo.initializeDefaults('company-1'), 23);
    expect(store.commitCount, 1);
    await expectLater(
      repo.initializeDefaults('../company-1'),
      throwsA(isA<ChartOfAccountsFailure>()),
    );
  });

  test(
    'Data bentrok/rusak menghentikan seed tanpa mengganti data yang ada',
    () async {
      final store = ChartStore();
      store.documents['companies/company-1/chart_of_accounts/4100'] = {
        'code': '4100',
        'name': 'Rusak',
        'type': 'asset',
      };
      final repo = FirebaseChartOfAccountsRepository(
        firestore: store,
        auth: CompanyAuth(),
      );
      await expectLater(
        repo.initializeDefaults('company-1'),
        throwsA(isA<ChartOfAccountsFailure>()),
      );
      expect(store.commitCount, 0);
      expect(
        store.documents['companies/company-1/chart_of_accounts/4100']!['type'],
        'asset',
      );
    },
  );

  test('Watch memakai scope perusahaan, mengabaikan cache/pending write, lalu membaca server', () async {
    final store = ChartStore();
    addTearDown(store.snapshots.close);
    final repo = FirebaseChartOfAccountsRepository(
      firestore: store,
      auth: CompanyAuth(),
    );
    final received = <List<ChartAccount>>[];
    final subscription = repo.watchAccounts('company-1').listen(received.add);
    addTearDown(subscription.cancel);
    await flushAuth();
    expect(store.queryPath, 'companies/company-1/chart_of_accounts');
    expect(store.orderField, 'code');
    store.snapshots.add(ChartSnapshot([], cached: true));
    store.snapshots.add(ChartSnapshot([], pending: true));
    await flushAuth();
    expect(received, isEmpty);
    final now = Timestamp.fromDate(DateTime.utc(2026));
    store.snapshots.add(
      ChartSnapshot(
        defaultChartOfAccounts
            .map(
              (account) => ChartDocument(account.code, {
                ...ChartAccountCodec.values(account),
                'createdBy': testUser.uid,
                'createdAt': now,
                'updatedAt': now,
              }),
            )
            .toList(),
      ),
    );
    await flushAuth();
    expect(received.single.length, 23);
    await subscription.cancel();
    expect(store.snapshots.hasListener, isFalse);
  });

  test(
    'Penolakan izin baca menjadi error aman dan bukan daftar kosong',
    () async {
      final store = ChartStore();
      addTearDown(store.snapshots.close);
      final repo = FirebaseChartOfAccountsRepository(
        firestore: store,
        auth: CompanyAuth(),
      );
      final result = expectLater(
        repo.watchAccounts('company-1'),
        emitsError(
          isA<ChartOfAccountsFailure>().having(
            (error) => error.message,
            'message',
            contains('Akses kategori akun ditolak'),
          ),
        ),
      );
      await flushAuth();
      store.snapshots.addError(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'internal details',
        ),
      );
      await result;
    },
  );
}
