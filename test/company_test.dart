import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finova/app/app.dart';
import 'package:finova/app/routes/app_router.dart';
import 'package:finova/app/theme/app_theme.dart';
import 'package:finova/features/company/application/company_controller.dart';
import 'package:finova/features/company/data/firebase_company_repository.dart';
import 'package:finova/features/company/domain/company.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_repository.dart';
import 'support/fake_company_repository.dart';

CompanyDraft draft({
  String name = '  CV Sejahtera  ',
  String type = 'Jasa',
  String email = '',
  String phone = '',
  String logo = '',
}) => CompanyDraft(
  name: name,
  businessType: type,
  bookkeepingStartDate: DateTime(2026, 1, 1),
  email: email,
  phoneNumber: phone,
  logoUrl: logo,
);

void main() {
  test('Validasi perusahaan, tanggal, email, telepon dan logo opsional', () {
    expect(draft().validate(), isNull);
    expect(draft(name: ' ').validate(), isNotNull);
    expect(draft(name: 'x' * 101).validate(), isNotNull);
    expect(draft(type: 'Unknown').validate(), isNotNull);
    expect(draft(email: 'invalid').validate(), isNotNull);
    expect(draft(phone: 'abc').validate(), isNotNull);
    expect(draft(logo: 'http://example.com/image.png').validate(), isNotNull);
    expect(draft(logo: 'https://').validate(), isNotNull);
    expect(draft(logo: 'https://example.com/image.png').validate(), isNull);
    expect(CompanyValidators.date(null), isNotNull);
    expect(CompanyValidators.date(DateTime(1899)), isNotNull);
    expect(CompanyValidators.date(DateTime(2101)), isNotNull);
  });

  test('Parsing membership aktif membedakan role dan gagal tertutup pada data rusak', () {
    final data = {
      'name': 'CV Sejahtera',
      'businessType': 'Jasa',
      'bookkeepingStartDate': Timestamp.fromDate(DateTime.utc(2026)),
      'createdBy': 'owner',
      'currency': 'IDR',
      'status': 'active',
      'logoUrl': null,
    };
    final member = {'uid': testUser.uid, 'role': 'finance', 'status': 'active'};
    final result = FirebaseCompanyRepository.parseContext(
      'company',
      testUser.uid,
      data,
      member,
    );
    expect(result.role, CompanyRole.finance);
    expect(
      () => FirebaseCompanyRepository.parseContext(
        'company',
        testUser.uid,
        data,
        {...member, 'role': 'admin'},
      ),
      throwsA(isA<CompanyFailure>()),
    );
    expect(
      () => FirebaseCompanyRepository.parseContext(
        'company',
        testUser.uid,
        data,
        {...member, 'uid': 'other'},
      ),
      throwsA(isA<CompanyFailure>()),
    );
    expect(
      () => FirebaseCompanyRepository.parseContext('company', testUser.uid, {
        ...data,
        'status': 'inactive',
      }, member),
      throwsA(isA<CompanyFailure>()),
    );
  });

  test('Tanpa perusahaan, create berhasil dan double submit ditolak', () async {
    final auth = await readyAuth();
    final repo = FakeCompanyRepository(hasCompany: false);
    final company = await readyCompany(auth, repository: repo);
    expect(company.phase, CompanyPhase.noCompany);
    repo.delay = Completer<void>();
    final first = company.createCompany(draft());
    expect(company.busy, isTrue);
    company.retry();
    expect(company.phase, CompanyPhase.noCompany);
    expect(await company.createCompany(draft()), isFalse);
    expect(repo.createCalls, 1);
    repo.delay!.complete();
    expect(await first, isTrue);
    await flushAuth();
    expect(company.phase, CompanyPhase.active);
    expect(company.context!.role, CompanyRole.manager);
    expect(await company.createCompany(draft()), isFalse);
    expect(repo.createCalls, 1);
  });

  test(
    'Kegagalan jaringan saat create mempertahankan onboarding dan dapat retry',
    () async {
      final auth = await readyAuth();
      final repo = FakeCompanyRepository(hasCompany: false);
      final company = await readyCompany(auth, repository: repo);
      repo.failure = const CompanyFailure('Jaringan terputus.');
      expect(await company.createCompany(draft()), isFalse);
      expect(company.phase, CompanyPhase.noCompany);
      expect(company.message, 'Jaringan terputus.');
      expect(company.busy, isFalse);
      repo.failure = null;
      expect(await company.createCompany(draft()), isTrue);
      await flushAuth();
      expect(company.phase, CompanyPhase.active);
    },
  );

  test('Logout menghapus perusahaan, hasil terlambat diabaikan, login membaca membership lagi', () async {
    final auth = await readyAuth();
    final repo = FakeCompanyRepository(hasCompany: false);
    final company = await readyCompany(auth, repository: repo);
    repo.delay = Completer<void>();
    final create = company.createCompany(draft());
    await auth.signOut();
    expect(company.context, isNull);
    expect(company.phase, CompanyPhase.waiting);
    repo.delay!.complete();
    expect(await create, isFalse);
    expect(company.context, isNull);
    await auth.signIn(testUser.email, 'password123');
    await flushAuth();
    expect(company.phase, CompanyPhase.active);
  });

  test('Undangan terverifikasi membuat Finance; akun tak terverifikasi tidak mengambil daftar', () async {
    final auth = await readyAuth();
    final repo = FakeCompanyRepository(hasCompany: false)..verified = false;
    final company = await readyCompany(auth, repository: repo);
    await company.loadInvitations();
    expect(repo.invitationCalls, 0);
    expect(company.emailVerified, isFalse);
    expect(await company.respond('invite', accept: true), isFalse);
    repo.verified = true;
    expect(await company.respond('invite', accept: true), isTrue);
    await flushAuth();
    expect(company.context!.role, CompanyRole.finance);
    expect(await company.inviteFinance('other@example.com'), isFalse);
  });

  testWidgets('Deep link wajib profil lalu perusahaan sebelum Dashboard', (
    tester,
  ) async {
    final authRepo = FakeAuthRepository(initialUser: testUser)
      ..profileCompleted = false;
    final auth = await readyAuth(repository: authRepo);
    final companyRepo = FakeCompanyRepository(hasCompany: false);
    final company = await readyCompany(auth, repository: companyRepo);
    final router = createAppRouter(
      auth: auth,
      company: company,
      initialLocation: '/reports',
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lengkapi profil Anda.'), findsOneWidget);
    await auth.completeProfile('Andi Wijaya', null);
    await tester.pumpAndSettle();
    expect(find.text('Ruang untuk bisnis Anda.'), findsOneWidget);
    for (final path in ['/', '/reports', '/settings', '/company/invitations']) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(find.text('Ruang untuk bisnis Anda.'), findsOneWidget);
      expect(find.text(testCompany.company.name), findsNothing);
    }
    expect(await company.createCompany(draft()), isTrue);
    await tester.pumpAndSettle();
    expect(find.text(testCompany.company.name), findsOneWidget);
    expect(find.text('Manager · Anggota aktif'), findsOneWidget);
    expect(find.text('Rp 48.750.000'), findsNothing);
    await auth.signOut();
    await tester.pumpAndSettle();
    expect(find.text('Selamat datang kembali.'), findsOneWidget);
  });

  testWidgets(
    'Loading/error/revokasi membership tidak membuka Dashboard dan retry tersedia',
    (tester) async {
      final auth = await readyAuth();
      final repo = FakeCompanyRepository()..delay = Completer<void>();
      final company = await readyCompany(auth, repository: repo);
      final router = createAppRouter(auth: auth, company: company);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Menyiapkan perusahaan.'), findsOneWidget);
      expect(find.text(testCompany.company.name), findsNothing);
      repo.delay!.complete();
      await tester.pumpAndSettle();
      expect(find.text(testCompany.company.name), findsOneWidget);
      repo.events.addError(const CompanyFailure('Membership tidak aktif.'));
      await tester.pumpAndSettle();
      expect(find.text(testCompany.company.name), findsNothing);
      expect(find.text('Membership tidak aktif.'), findsOneWidget);
      await tester.ensureVisible(find.text('Coba lagi'));
      await tester.tap(find.text('Coba lagi'));
      await tester.pumpAndSettle();
      expect(find.text(testCompany.company.name), findsOneWidget);
    },
  );

  testWidgets('Form perusahaan menampilkan validasi wajib dan field logo', (
    tester,
  ) async {
    final auth = await readyAuth();
    final repo = FakeCompanyRepository(hasCompany: false);
    final company = await readyCompany(auth, repository: repo);
    final router = createAppRouter(
      auth: auth,
      company: company,
      initialLocation: '/company/create',
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, 'Buat perusahaan');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Nama perusahaan minimal 2 karakter.'), findsOneWidget);
    expect(find.text('Pilih jenis usaha.'), findsOneWidget);
    expect(
      find.text('Pilih tanggal pembukuan antara tahun 1900–2100.'),
      findsOneWidget,
    );
    expect(repo.createCalls, 0);
    expect(find.text('URL logo (opsional)'), findsOneWidget);
  });

  testWidgets(
    'Form lengkap menyimpan tanggal, menjaga input saat gagal dan berhasil lewat retry',
    (tester) async {
      final auth = await readyAuth();
      final repo = FakeCompanyRepository(hasCompany: false);
      final company = await readyCompany(auth, repository: repo);
      final router = createAppRouter(
        auth: auth,
        company: company,
        initialLocation: '/company/create',
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'CV Uji Form');
      final business = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(business);
      await tester.tap(business);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jasa').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Pilih tanggal'));
      await tester.tap(find.text('Pilih tanggal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      repo.failure = const CompanyFailure('Koneksi terputus saat menyimpan.');
      final save = find.widgetWithText(FilledButton, 'Buat perusahaan');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Koneksi terputus saat menyimpan.'), findsOneWidget);
      expect(find.text('CV Uji Form'), findsOneWidget);
      expect(repo.createCalls, 1);
      repo.failure = null;
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repo.savedDraft!.name, 'CV Uji Form');
      expect(repo.savedDraft!.businessType, 'Jasa');
      expect(repo.savedDraft!.bookkeepingStartDate.year, DateTime.now().year);
      expect(find.text('Manager · Anggota aktif'), findsOneWidget);
    },
  );

  testWidgets('Finance ditolak dari pengelolaan undangan Manager', (
    tester,
  ) async {
    final auth = await readyAuth();
    final repo = FakeCompanyRepository()
      ..value = CompanyContext(
        company: testCompany.company,
        role: CompanyRole.finance,
      );
    final company = await readyCompany(auth, repository: repo);
    final router = createAppRouter(
      auth: auth,
      company: company,
      initialLocation: '/company/invitations',
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();
    expect(find.text('Finance · Anggota aktif'), findsOneWidget);
    expect(find.text('Undang tim Finance.'), findsNothing);
  });

  testWidgets(
    'Form perusahaan responsif pada 320dp dengan keyboard dan teks besar',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final auth = await readyAuth();
      await tester.pumpWidget(
        FinovaApp(
          authController: auth,
          companyRepository: FakeCompanyRepository(hasCompany: false),
        ),
      );
      await tester.pumpAndSettle();
      final choice = find.widgetWithText(TextButton, 'Buat perusahaan baru');
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Buat perusahaan'),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
