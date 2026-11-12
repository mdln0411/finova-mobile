import 'package:finova/features/auth/data/firebase_auth_repository.dart';
import 'package:finova/features/auth/data/firebase_auth_service.dart';
import 'package:finova/features/auth/data/google_sign_in_service.dart';
import 'package:finova/features/auth/data/user_profile_service.dart';
import 'package:finova/features/auth/domain/auth_failure.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAccountStub extends Fake implements GoogleSignInAccount {
  GoogleAccountStub({this.token = 'local-test-token'});
  final String? token;
  @override
  GoogleSignInAuthentication get authentication =>
      GoogleSignInAuthentication(idToken: token);
}

class GoogleClientStub extends Fake implements GoogleSignIn {
  GoogleAccountStub account = GoogleAccountStub();
  int initializes = 0;
  int signOuts = 0;
  Object? failure;
  @override
  Future<void> initialize({
    String? clientId,
    String? serverClientId,
    String? nonce,
    String? hostedDomain,
  }) async {
    initializes++;
  }

  @override
  bool supportsAuthenticate() => true;
  @override
  Future<GoogleSignInAccount> authenticate({
    List<String> scopeHint = const [],
  }) async {
    if (failure != null) throw failure!;
    return account;
  }

  @override
  Future<void> signOut() async {
    signOuts++;
  }
}

class ResetServiceStub extends Fake implements FirebaseAuthService {
  Object? failure;
  @override
  Future<void> sendPasswordReset(String email) async {
    if (failure != null) throw failure!;
  }
}

class ProfileServiceStub extends Fake implements UserProfileService {}

void main() {
  test('Google 7.x hanya diinisialisasi sekali dan sesi yang dipulihkan bisa logout', () async {
    final client = GoogleClientStub();
    final service = GoogleSignInService(google: client);
    await service.signOut(initialize: true);
    expect(client.initializes, 1);
    expect(client.signOuts, 1);
    expect(await service.authenticate(), 'local-test-token');
    expect(client.initializes, 1);
  });

  test('Google yang dibatalkan tidak menghasilkan credential; token kosong ditolak', () async {
    final client = GoogleClientStub()
      ..failure = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );
    final service = GoogleSignInService(google: client);
    await expectLater(
      service.authenticate(),
      throwsA(isA<GoogleSignInException>()),
    );
    client.failure = null;
    client.account = GoogleAccountStub(token: null);
    await expectLater(service.authenticate(), throwsA(isA<AuthFailure>()));
  });

  test('Reset email tidak ditemukan/dinonaktifkan diberi respons yang sama dengan sukses', () async {
    final auth = ResetServiceStub();
    final repository = FirebaseAuthRepository(
      auth: auth,
      profiles: ProfileServiceStub(),
    );
    await repository.sendPasswordReset('known@example.com');
    for (final code in ['user-not-found', 'user-disabled']) {
      auth.failure = FirebaseAuthException(code: code);
      await repository.sendPasswordReset('unknown@example.com');
    }
  });

  test(
    'Reset gagal jaringan tetap dapat dicoba ulang tanpa memaparkan pesan SDK',
    () async {
      final auth = ResetServiceStub()
        ..failure = FirebaseAuthException(
          code: 'network-request-failed',
          message: 'private-sdk-details',
        );
      final repository = FirebaseAuthRepository(
        auth: auth,
        profiles: ProfileServiceStub(),
      );
      await expectLater(
        repository.sendPasswordReset('andi@example.com'),
        throwsA(
          isA<AuthFailure>().having(
            (error) => error.message,
            'safe message',
            allOf(contains('Koneksi'), isNot(contains('private-sdk-details'))),
          ),
        ),
      );
    },
  );
}
