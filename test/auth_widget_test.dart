import 'support/fake_company_repository.dart';

import 'dart:async';

import 'package:finova/app/app.dart';
import 'package:finova/app/bootstrap.dart';
import 'package:finova/app/routes/app_router.dart';
import 'package:finova/app/theme/app_theme.dart';
import 'package:finova/features/auth/application/auth_controller.dart';
import 'package:finova/features/auth/domain/auth_failure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_repository.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

void main() {
  Future<AuthController> signedOut(
    WidgetTester tester,
    FakeAuthRepository repo,
  ) async {
    final auth = await readyAuth(repository: repo);
    await tester.pumpWidget(
      FinovaApp(
        authController: auth,
        companyRepository: FakeCompanyRepository(),
      ),
    );
    await tester.pumpAndSettle();
    return auth;
  }

  testWidgets('Form login menolak input kosong dan email tidak valid', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    await signedOut(tester, repo);
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pumpAndSettle();
    expect(find.text('Masukkan alamat email Anda.'), findsOneWidget);
    expect(find.text('Masukkan password Anda.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'invalid');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pumpAndSettle();
    expect(find.text('Masukkan alamat email yang valid.'), findsOneWidget);
    expect(repo.signInCalls, 0);
  });

  testWidgets('Register memvalidasi konfirmasi sebelum membuat akun', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    await signedOut(tester, repo);
    await tapVisible(tester, find.text('Daftar sekarang'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Andi');
    await tester.enterText(fields.at(1), 'andi@example.com');
    await tester.enterText(fields.at(2), 'password123');
    await tester.enterText(fields.at(3), 'different');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Buat akun'));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Buat akun'));
    await tester.pumpAndSettle();
    expect(find.text('Konfirmasi password belum sesuai.'), findsOneWidget);
    expect(repo.registerCalls, 0);
    await tester.enterText(fields.at(3), 'password123');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Buat akun'));
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Buat akun'));
    await tester.pumpAndSettle();
    expect(repo.registerCalls, 1);
    expect(find.text('Lengkapi profil Anda.'), findsOneWidget);
  });

  testWidgets(
    'Login loading, sesi masuk, logout dan kembali tidak membuka Dashboard',
    (tester) async {
      final repo = FakeAuthRepository()..actionDelay = Completer<void>();
      await signedOut(tester, repo);
      await tester.enterText(
        find.byType(TextFormField).first,
        'andi@example.com',
      );
      await tester.enterText(find.byType(TextFormField).last, 'password123');
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Masuk'));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Masuk'));
      await tester.pump();
      expect(repo.signInCalls, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      repo.actionDelay!.complete();
      await tester.pumpAndSettle();
      expect(find.text('CV Finova Sejahtera'), findsOneWidget);
      await tapVisible(tester, find.byTooltip('Pengaturan'));
      await tester.pumpAndSettle();
      expect(find.text(testUser.email), findsOneWidget);
      await tapVisible(tester, find.text('Keluar dari akun'));
      await tester.pumpAndSettle();
      expect(find.text('Selamat datang kembali.'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Rp 48.750.000'), findsNothing);
    },
  );

  testWidgets('Google dibatalkan memberi pesan dan tetap di Login', (
    tester,
  ) async {
    final repo = FakeAuthRepository()
      ..actionError = const AuthFailure('Login Google dibatalkan.');
    await signedOut(tester, repo);
    await tester.ensureVisible(find.text('Continue with Google'));
    await tapVisible(tester, find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(find.text('Login Google dibatalkan.'), findsOneWidget);
    expect(find.text('Rp 48.750.000'), findsNothing);
  });

  testWidgets('Reset menampilkan konfirmasi netral tanpa membuat sesi', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    await signedOut(tester, repo);
    await tapVisible(tester, find.text('Lupa password?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'unknown@example.com');
    await tapVisible(tester, find.text('Kirim tautan reset'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Jika email tersebut terdaftar'),
      findsOneWidget,
    );
    expect(repo.resetCalls, 1);
    expect(repo.currentUser, isNull);
  });

  testWidgets('Tidak ada Dashboard sesaat ketika sesi awal belum diketahui', (
    tester,
  ) async {
    final repo = FakeAuthRepository(emitInitial: false);
    final auth = await readyAuth(repository: repo);
    await tester.pumpWidget(
      FinovaApp(
        authController: auth,
        companyRepository: FakeCompanyRepository(),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Menyiapkan ruang kerja.'), findsOneWidget);
    expect(find.text('Rp 48.750.000'), findsNothing);
    repo.emit(null);
    await tester.pumpAndSettle();
    expect(find.text('Selamat datang kembali.'), findsOneWidget);
  });

  testWidgets(
    'Deep link dilindungi dan perubahan sesi mengunci kembali Dashboard',
    (tester) async {
      final repo = FakeAuthRepository();
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
      expect(find.text('Selamat datang kembali.'), findsOneWidget);
      repo.emit(testUser);
      await tester.pumpAndSettle();
      expect(find.text('CV Finova Sejahtera'), findsOneWidget);
      repo.emit(null);
      await tester.pumpAndSettle();
      expect(find.text('Rp 48.750.000'), findsNothing);
      expect(find.text('Selamat datang kembali.'), findsOneWidget);
    },
  );

  testWidgets(
    'Profil ditolak ditampilkan sebagai pemulihan, tanpa register ulang',
    (tester) async {
      final repo = FakeAuthRepository(initialUser: testUser)
        ..profileError = const AuthFailure('Izin profil ditolak.');
      final auth = await readyAuth(repository: repo);
      await tester.pumpWidget(
        FinovaApp(
          authController: auth,
          companyRepository: FakeCompanyRepository(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Izin profil ditolak.'), findsOneWidget);
      expect(find.text('Rp 48.750.000'), findsNothing);
      repo.profileError = null;
      await tapVisible(tester, find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text('CV Finova Sejahtera'), findsOneWidget);
    },
  );

  testWidgets('Inisialisasi gagal menyediakan retry dengan satu permintaan', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    addTearDown(repo.dispose);
    final ready = Completer<AuthController>();
    var attempts = 0;
    await tester.pumpWidget(
      FinovaBootstrap(
        initialize: () {
          attempts++;
          return ready.future;
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Belum dapat terhubung.'), findsOneWidget);
    await tapVisible(tester, find.text('Coba hubungkan kembali'));
    await tester.pump();
    expect(attempts, 1);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    ready.complete(AuthController(repo));
    await tester.pumpAndSettle();
    expect(find.text('Selamat datang kembali.'), findsOneWidget);
  });

  for (final label in ['login', 'register', 'reset']) {
    testWidgets('Form $label responsif dengan keyboard dan teks besar', (
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
      await signedOut(tester, FakeAuthRepository());
      if (label != 'login') {
        final target = find.text(
          label == 'register' ? 'Daftar sekarang' : 'Lupa password?',
        );
        await tester.ensureVisible(target);
        await tapVisible(tester, target);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.byType(FilledButton));
      await tapVisible(tester, find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Masukkan alamat email Anda.'), findsOneWidget);
    });
  }
}
