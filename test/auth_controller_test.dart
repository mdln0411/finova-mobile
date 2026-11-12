import 'dart:async';

import 'package:finova/features/auth/application/auth_controller.dart';
import 'package:finova/features/auth/domain/auth_failure.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_repository.dart';

void main() {
  test(
    'Sesi awal menunggu event Firebase; sesi tersimpan dipulihkan',
    () async {
      final repo = FakeAuthRepository(emitInitial: false);
      final auth = await readyAuth(repository: repo);
      expect(auth.phase, AuthPhase.loading);
      expect(auth.user, isNull);
      repo.emit(testUser);
      await flushAuth();
      expect(auth.phase, AuthPhase.signedIn);
      expect(auth.profile?.uid, testUser.uid);
    },
  );

  test('Login gagal dan Google dibatalkan tidak menciptakan sesi', () async {
    final repo = FakeAuthRepository();
    final auth = await readyAuth(repository: repo);
    repo.actionError = const AuthFailure('Login Google dibatalkan.');
    expect(await auth.signInWithGoogle(), isFalse);
    expect(auth.phase, AuthPhase.signedOut);
    expect(auth.actionMessage, 'Login Google dibatalkan.');
    expect(repo.profileCalls, 0);
    repo.actionError = const AuthFailure('Email atau password tidak sesuai.');
    expect(await auth.signIn('andi@example.com', 'wrong'), isFalse);
    expect(auth.phase, AuthPhase.signedOut);
  });

  test('Submit ganda dibatasi dan password tidak dipangkas', () async {
    final repo = FakeAuthRepository()..actionDelay = Completer<void>();
    final auth = await readyAuth(repository: repo);
    final first = auth.register('Andi', 'andi@example.com', ' password ');
    expect(auth.busy, isTrue);
    expect(
      await auth.register('Andi', 'andi@example.com', ' password '),
      isFalse,
    );
    repo.actionDelay!.complete();
    expect(await first, isTrue);
    expect(repo.registerCalls, 1);
    expect(repo.lastPassword, ' password ');
    expect(auth.phase, AuthPhase.profileIncomplete);
  });

  test('Profil gagal dapat dicoba ulang tanpa registrasi ulang', () async {
    final repo = FakeAuthRepository()
      ..profileError = const AuthFailure('Izin profil ditolak.');
    final auth = await readyAuth(repository: repo);
    await auth.register('Andi', 'andi@example.com', 'password123');
    expect(auth.phase, AuthPhase.profileError);
    expect(auth.user?.uid, testUser.uid);
    expect(auth.profile, isNull);
    repo.profileError = null;
    await auth.retrySession();
    expect(auth.phase, AuthPhase.profileIncomplete);
    expect(repo.registerCalls, 1);
  });

  test(
    'Logout dan event signout membatalkan hasil profil yang terlambat',
    () async {
      final repo = FakeAuthRepository(initialUser: testUser)
        ..profileDelay = Completer<void>();
      final auth = await readyAuth(repository: repo);
      expect(auth.phase, AuthPhase.loading);
      await auth.signOut();
      expect(auth.phase, AuthPhase.signedOut);
      repo.profileDelay!.complete();
      await flushAuth();
      expect(auth.phase, AuthPhase.signedOut);
      expect(auth.profile, isNull);
    },
  );

  test('Sesi gagal dibaca ditahan, event valid dapat memulihkan', () async {
    final repo = FakeAuthRepository();
    final auth = await readyAuth(repository: repo);
    repo.failStream();
    await flushAuth();
    expect(auth.phase, AuthPhase.sessionError);
    repo.emit(null);
    await flushAuth();
    expect(auth.phase, AuthPhase.signedOut);
  });

  test('Reset password tidak mengubah sesi', () async {
    final repo = FakeAuthRepository();
    final auth = await readyAuth(repository: repo);
    expect(await auth.sendPasswordReset('unknown@example.com'), isTrue);
    expect(auth.phase, AuthPhase.signedOut);
    expect(repo.resetCalls, 1);
  });

  test('Retry profil ganda tidak memulai dua sinkronisasi', () async {
    final repo = FakeAuthRepository(initialUser: testUser)
      ..profileError = const AuthFailure('Izin profil ditolak.');
    final auth = await readyAuth(repository: repo);
    repo.profileError = null;
    repo.profileDelay = Completer<void>();
    final first = auth.retrySession();
    await auth.retrySession();
    expect(auth.busy, isTrue);
    expect(repo.profileCalls, 2);
    repo.profileDelay!.complete();
    await first;
    expect(auth.phase, AuthPhase.signedIn);
    expect(auth.busy, isFalse);
  });
}
