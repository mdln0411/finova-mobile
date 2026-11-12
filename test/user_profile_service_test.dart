import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finova/features/auth/data/user_profile_service.dart';
import 'package:finova/features/auth/domain/auth_failure.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_repository.dart';

// Test double untuk kontrak SDK; tidak digunakan oleh aplikasi.
// ignore: subtype_of_sealed_class
class ProfileReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  @override
  String get path => 'users/test-user';
}

// ignore: subtype_of_sealed_class
class ProfileCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final requestedUids = <String?>[];
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    requestedUids.add(path);
    return ProfileReference();
  }
}

// ignore: subtype_of_sealed_class
class ProfileSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  ProfileSnapshot(this.value);
  final Map<String, dynamic>? value;
  @override
  Map<String, dynamic>? data() => value;
  @override
  bool get exists => value != null;
}

class ProfileTransaction extends Fake implements Transaction {
  Map<String, dynamic>? value;
  Object? readFailure;
  int sets = 0;
  int updates = 0;
  String? path;
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) async {
    path = reference.path;
    if (readFailure != null) throw readFailure!;
    return ProfileSnapshot(value) as DocumentSnapshot<T>;
  }

  @override
  Transaction set<T>(
    DocumentReference<T> reference,
    T data, [
    SetOptions? options,
  ]) {
    sets++;
    value = Map<String, dynamic>.from(data as Map);
    return this;
  }

  @override
  Transaction update(
    DocumentReference<Object?> reference,
    Map<Object, Object?> data,
  ) {
    updates++;
    value!.addAll(data.map((key, value) => MapEntry(key as String, value)));
    return this;
  }
}

class ProfileFirestore extends Fake implements FirebaseFirestore {
  final transaction = ProfileTransaction();
  final profiles = ProfileCollection();
  Object? commitFailure;
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    expect(path, 'users');
    return profiles;
  }

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final result = await transactionHandler(transaction);
    if (commitFailure != null) throw commitFailure!;
    return result;
  }
}

void main() {
  test(
    'Profil hilang dibuat pada UID sendiri dengan server timestamp tanpa role',
    () async {
      final store = ProfileFirestore();
      final result = await UserProfileService(firestore: store)
          .ensureProfile(testUser);
      expect(result.uid, testUser.uid);
      expect(store.profiles.requestedUids.single, testUser.uid);
      expect(store.transaction.path, 'users/test-user');
      expect(store.transaction.sets, 1);
      expect(store.transaction.value!.keys.toSet(), {
        'uid',
        'displayName',
        'email',
        'photoUrl',
        'createdAt',
        'updatedAt',
        'profileCompleted',
      });
      expect(store.transaction.value!['createdAt'], isA<FieldValue>());
      expect(store.transaction.value!['updatedAt'], isA<FieldValue>());
    },
  );
  test('Login ulang memakai dokumen sama, mempertahankan createdAt, tanpa penulisan ulang', () async {
    final store = ProfileFirestore();
    final service = UserProfileService(firestore: store);
    await service.ensureProfile(testUser);
    final createdAt = store.transaction.value!['createdAt'];
    store.transaction.value!['displayName'] = 'Nama profil tersimpan';
    final loaded = await service.ensureProfile(testUser);
    expect(loaded.displayName, 'Nama profil tersimpan');
    expect(store.transaction.sets, 1);
    expect(store.transaction.updates, 0);
    expect(store.transaction.value!['createdAt'], same(createdAt));
  });
  test(
    'Izin baca ditolak dibedakan dari izin pembuatan, tanpa mencoba menulis',
    () async {
      final store = ProfileFirestore()
        ..transaction.readFailure = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
      await expectLater(
        UserProfileService(firestore: store).ensureProfile(testUser),
        throwsA(
          isA<ProfileSyncFailure>()
              .having((e) => e.operation, 'operation', 'read')
              .having((e) => e.code, 'code', 'permission-denied'),
        ),
      );
      expect(store.transaction.sets, 0);
    },
  );
  test(
    'Penolakan commit pembuatan tetap dilaporkan sebagai penolakan izin',
    () async {
      final store = ProfileFirestore()
        ..commitFailure = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
      await expectLater(
        UserProfileService(firestore: store).ensureProfile(testUser),
        throwsA(
          isA<ProfileSyncFailure>().having(
            (e) => e.operation,
            'operation',
            'create',
          ),
        ),
      );
    },
  );
  test('Baca gagal dapat dipulihkan, profil hilang dibuat sekali setelah izin tersedia', () async {
    final store = ProfileFirestore()
      ..transaction.readFailure = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    final service = UserProfileService(firestore: store);
    await expectLater(
      service.ensureProfile(testUser),
      throwsA(isA<ProfileSyncFailure>()),
    );
    store.transaction.readFailure = null;
    expect((await service.ensureProfile(testUser)).uid, testUser.uid);
    await service.ensureProfile(testUser);
    expect(store.transaction.sets, 1);
  });
  test('UID profil berbeda tidak ditimpa atau diterima', () async {
    final store = ProfileFirestore()
      ..transaction.value = {'uid': 'other-user', 'displayName': 'Nama'};
    await expectLater(
      UserProfileService(firestore: store).ensureProfile(testUser),
      throwsA(isA<AuthFailure>()),
    );
    expect(store.transaction.sets, 0);
    expect(store.transaction.updates, 0);
  });
  test(
    'Gangguan jaringan tidak disamarkan menjadi permission-denied',
    () async {
      final store = ProfileFirestore()
        ..transaction.readFailure = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'unavailable',
        );
      await expectLater(
        UserProfileService(firestore: store).ensureProfile(testUser),
        throwsA(
          isA<ProfileSyncFailure>().having(
            (e) => e.code,
            'code',
            'unavailable',
          ),
        ),
      );
    },
  );
}
