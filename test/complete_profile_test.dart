import 'support/fake_company_repository.dart';

import 'dart:async';

import 'package:finova/app/app.dart';
import 'package:finova/app/routes/app_router.dart';
import 'package:finova/app/theme/app_theme.dart';
import 'package:finova/features/auth/application/auth_controller.dart';
import 'package:finova/features/auth/data/user_profile_service.dart';
import 'package:finova/features/auth/domain/auth_failure.dart';
import 'package:finova/features/auth/domain/auth_validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_repository.dart';
import 'user_profile_service_test.dart' show ProfileFirestore;

void main() {
  test('Nama wajib dan nomor opsional divalidasi serta dinormalisasi', () {
    expect(AuthValidators.name('  '), isNotNull);
    expect(AuthValidators.name(' A '), isNotNull);
    expect(AuthValidators.name('  Andi  '), isNull);
    expect(AuthValidators.phone(''), isNull);
    expect(AuthValidators.phone(null), isNull);
    expect(AuthValidators.phone('abc12345'), isNotNull);
    expect(AuthValidators.phone('123'), isNotNull);
    expect(AuthValidators.phone('1' * 16), isNotNull);
    expect(AuthValidators.phone('+62 (812) 3456-7890'), isNull);
    expect(
      AuthValidators.normalizePhone('+62 (812) 3456-7890'),
      '+6281234567890',
    );
  });

  test(
    'Profil legacy tanpa status belum lengkap, tidak ditulis ulang',
    () async {
      final store = ProfileFirestore()
        ..transaction.value = {
          'uid': testUser.uid,
          'displayName': 'Andi',
          'photoUrl': null,
        };
      final profile = await UserProfileService(firestore: store)
          .ensureProfile(testUser);
      expect(profile.profileCompleted, isFalse);
      expect(store.transaction.updates, 0);
    },
  );

  test('Penyelesaian profil menyimpan data sendiri, mempertahankan UID dan createdAt', () async {
    final created = Object();
    final store = ProfileFirestore()
      ..transaction.value = {
        'uid': testUser.uid,
        'displayName': 'Andi',
        'createdAt': created,
        'photoUrl': 'https://example.com/google-avatar.jpg',
      };
    final service = UserProfileService(firestore: store);
    final saved = await service.completeProfile(
      testUser,
      '  Andi Wijaya  ',
      '+62 812-3456-7890',
    );
    expect(saved.profileCompleted, isTrue);
    expect(saved.displayName, 'Andi Wijaya');
    expect(saved.phoneNumber, '+6281234567890');
    expect(saved.email, testUser.email);
    expect(saved.photoUrl, 'https://example.com/google-avatar.jpg');
    expect(store.transaction.value!['createdAt'], same(created));
    expect(store.transaction.value!['uid'], testUser.uid);
    expect(store.transaction.value!['role'], isNull);
    expect(store.transaction.value!['profileCompleted'], isTrue);
    expect((await service.ensureProfile(testUser)).profileCompleted, isTrue);
  });

  test(
    'Simpan memulihkan dokumen hilang dan menolak nama invalid tanpa write',
    () async {
      final store = ProfileFirestore();
      final service = UserProfileService(firestore: store);
      await expectLater(
        service.completeProfile(testUser, ' ', null),
        throwsA(isA<AuthFailure>()),
      );
      expect(store.transaction.sets, 0);
      final saved = await service.completeProfile(testUser, 'Andi', '');
      expect(saved.phoneNumber, isNull);
      expect(store.transaction.sets, 1);
      expect(store.transaction.value!['profileCompleted'], isTrue);
      await service.completeProfile(testUser, 'Andi', null);
      expect(store.transaction.sets, 1);
    },
  );

  test('Simpan profil berbeda UID ditolak tanpa mutasi', () async {
    final store = ProfileFirestore()
      ..transaction.value = {'uid': 'someone-else'};
    await expectLater(
      UserProfileService(firestore: store)
          .completeProfile(testUser, 'Andi', null),
      throwsA(isA<AuthFailure>()),
    );
    expect(store.transaction.updates, 0);
    expect(store.transaction.sets, 0);
  });

  test('Status lengkap tersimpan melewati pemulihan sesi berikutnya', () async {
    final repo = FakeAuthRepository(initialUser: testUser)
      ..profileCompleted = false;
    final auth = await readyAuth(repository: repo);
    expect(auth.phase, AuthPhase.profileIncomplete);
    expect(await auth.completeProfile('Andi', null), isTrue);
    expect(auth.phase, AuthPhase.signedIn);
    await auth.signOut();
    await auth.signIn('andi@example.com', 'password123');
    expect(auth.phase, AuthPhase.signedIn);
    expect(repo.completeProfileCalls, 1);
  });

  test('Hasil simpan terlambat tidak menghidupkan sesi setelah logout eksternal', () async {
    final repo = FakeAuthRepository(initialUser: testUser)
      ..profileCompleted = false;
    final auth = await readyAuth(repository: repo);
    repo.actionDelay = Completer<void>();
    final save = auth.completeProfile('Andi', null);
    repo.emit(null);
    await flushAuth();
    // Simulasikan respons server yang datang setelah sesi di perangkat hilang.
    repo.actionError = const AuthFailure('Sesi berakhir.');
    repo.actionDelay!.complete();
    await save;
    expect(auth.phase, AuthPhase.signedOut);
    expect(auth.profile, isNull);
  });

  testWidgets(
    'Pengguna belum lengkap ditahan dari laporan, email read-only, lalu simpan ke Dashboard',
    (tester) async {
      final repo = FakeAuthRepository(initialUser: testUser)
        ..profileCompleted = false;
      final auth = await readyAuth(repository: repo);
      final router = createAppRouter(
        auth: auth,
        company: await readyCompany(auth),
        initialLocation: '/reports',
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lengkapi profil Anda.'), findsOneWidget);
      expect(find.text('Rp 48.750.000'), findsNothing);
      final fields = find.byType(TextFormField);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: fields.at(1),
                matching: find.byType(TextField),
              ),
            )
            .readOnly,
        isTrue,
      );
      expect(find.text(testUser.email), findsOneWidget);
      await tester.enterText(fields.first, ' ');
      final button = find.text('Simpan dan lanjutkan');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Masukkan nama lengkap Anda.'), findsOneWidget);
      expect(repo.completeProfileCalls, 0);
      await tester.enterText(fields.first, 'Andi Wijaya');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('CV Finova Sejahtera'), findsOneWidget);
    },
  );

  testWidgets('Simpan gagal mempertahankan form dan memungkinkan retry', (
    tester,
  ) async {
    final repo = FakeAuthRepository(initialUser: testUser)
      ..profileCompleted = false;
    final auth = await readyAuth(repository: repo);
    repo.actionError = const AuthFailure('Izin penyimpanan ditolak.');
    await tester.pumpWidget(
      FinovaApp(
        authController: auth,
        companyRepository: FakeCompanyRepository(),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.text('Simpan dan lanjutkan');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Izin penyimpanan ditolak.'), findsOneWidget);
    expect(auth.phase, AuthPhase.profileIncomplete);
    repo.actionError = null;
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('CV Finova Sejahtera'), findsOneWidget);
  });

  testWidgets(
    'Profil lengkap melewati halaman pengisian; tamu dialihkan ke Login',
    (tester) async {
      final auth = await readyAuth();
      final router = createAppRouter(
        auth: auth,
        company: await readyCompany(auth),
        initialLocation: '/complete-profile',
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );
      await tester.pumpAndSettle();
      expect(find.text('CV Finova Sejahtera'), findsOneWidget);
      await auth.signOut();
      router.go('/complete-profile');
      await tester.pumpAndSettle();
      expect(find.text('Selamat datang kembali.'), findsOneWidget);
      expect(find.text('Lengkapi profil Anda.'), findsNothing);
    },
  );

  testWidgets('Halaman profil dapat logout dan responsif dengan keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repo = FakeAuthRepository(initialUser: testUser)
      ..profileCompleted = false;
    final auth = await readyAuth(repository: repo);
    await tester.pumpWidget(
      FinovaApp(
        authController: auth,
        companyRepository: FakeCompanyRepository(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Keluar dari akun'));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Keluar dari akun'));
    await tester.pumpAndSettle();
    expect(find.text('Selamat datang kembali.'), findsOneWidget);
  });
}
