import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:finova/features/company/data/firebase_company_repository.dart';
import 'package:finova/features/company/domain/company.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_repository.dart';

class CompanyAuthUser extends Fake implements User {
  @override
  String get uid => testUser.uid;
}

class CompanyAuth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => CompanyAuthUser();
}

// Test doubles SDK hanya dipakai untuk menguji kontrak transaksi repository.
// ignore: subtype_of_sealed_class
class CompanyRef extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  CompanyRef(this.path);
  @override
  final String path;
  @override
  String get id => path.split('/').last;
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      CompanyCollection('$path/$collectionPath');
}

// ignore: subtype_of_sealed_class
class CompanyCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  CompanyCollection(this.path);
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      CompanyRef('${this.path}/$path');
}

// ignore: subtype_of_sealed_class
class CompanySnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  CompanySnapshot(this.value);
  final Map<String, dynamic>? value;
  @override
  bool get exists => value != null;
  @override
  Map<String, dynamic>? data() => value;
}

class CompanyTransaction extends Fake implements Transaction {
  CompanyTransaction(this.documents);
  final Map<String, Map<String, dynamic>> documents;
  final writes = <String, Map<String, dynamic>>{};
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) async => CompanySnapshot(documents[reference.path]) as DocumentSnapshot<T>;
  @override
  Transaction set<T>(
    DocumentReference<T> reference,
    T data, [
    SetOptions? options,
  ]) {
    writes[reference.path] = Map<String, dynamic>.from(data as Map);
    return this;
  }
}

class CompanyStore extends Fake implements FirebaseFirestore {
  final documents = <String, Map<String, dynamic>>{
    'users/${testUser.uid}': {'uid': testUser.uid, 'profileCompleted': true},
  };
  int commitCount = 0;
  Object? commitFailure;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      CompanyCollection(path);
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final transaction = CompanyTransaction(documents);
    final result = await transactionHandler(transaction);
    if (commitFailure != null) throw commitFailure!;
    if (transaction.writes.isNotEmpty) {
      documents.addAll(transaction.writes);
      commitCount++;
    }
    return result;
  }
}

void main() {
  CompanyDraft draft() => CompanyDraft(
    name: ' CV Sejahtera ',
    businessType: 'Jasa',
    bookkeepingStartDate: DateTime(2026, 1, 2),
    phoneNumber: '+62 812-3456-789',
    logoSvg: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10"/></svg>',
  );

  test('Repository mengomit tiga dokumen atomik, Manager hanya di perusahaan baru sendiri, retry idempoten', () async {
    final store = CompanyStore();
    final repository = FirebaseCompanyRepository(
      firestore: store,
      auth: CompanyAuth(),
    );
    await repository.createCompany(draft());
    final uid = testUser.uid;
    expect(store.commitCount, 1);
    expect(store.documents.keys.toSet(), {
      'users/$uid',
      'companies/$uid',
      'companies/$uid/members/$uid',
      'company_access/$uid',
    });
    final company = store.documents['companies/$uid']!;
    expect(company['name'], 'CV Sejahtera');
    expect(company['currency'], 'IDR');
    expect(company['createdBy'], uid);
    expect(company['createdAt'], isA<FieldValue>());
    expect(company['phoneNumber'], '+628123456789');
    expect(
      (company['bookkeepingStartDate'] as Timestamp).toDate().toUtc(),
      DateTime.utc(2026, 1, 2),
    );
    expect(store.documents['companies/$uid/members/$uid']!['role'], 'manager');
    await repository.createCompany(draft());
    expect(store.commitCount, 1);
    expect(store.documents['companies/$uid'], same(company));
  });
  test('Commit gagal tidak menyisakan perusahaan atau membership parsial, retry aman', () async {
    final store = CompanyStore()
      ..commitFailure = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
    final repository = FirebaseCompanyRepository(
      firestore: store,
      auth: CompanyAuth(),
    );
    await expectLater(
      repository.createCompany(draft()),
      throwsA(isA<CompanyFailure>()),
    );
    expect(store.documents.length, 1);
    store.commitFailure = null;
    await repository.createCompany(draft());
    expect(store.documents.length, 4);
    expect(store.commitCount, 1);
  });
  test(
    'Profil belum lengkap dan formulir invalid tidak menulis perusahaan',
    () async {
      final store = CompanyStore();
      store.documents['users/${testUser.uid}']!['profileCompleted'] = false;
      final repository = FirebaseCompanyRepository(
        firestore: store,
        auth: CompanyAuth(),
      );
      await expectLater(
        repository.createCompany(draft()),
        throwsA(isA<CompanyFailure>()),
      );
      expect(store.commitCount, 0);
      await expectLater(
        repository.createCompany(
          CompanyDraft(
            name: '',
            businessType: 'Jasa',
            bookkeepingStartDate: DateTime(2026),
          ),
        ),
        throwsA(isA<CompanyFailure>()),
      );
      expect(store.commitCount, 0);
    },
  );
}
