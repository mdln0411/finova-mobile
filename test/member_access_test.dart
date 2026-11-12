import 'package:finova/app/routes/app_router.dart';
import 'package:finova/app/theme/app_theme.dart';
import 'package:finova/features/company/data/firebase_company_repository.dart';
import 'package:finova/features/company/domain/company.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_repository.dart';
import 'support/fake_company_repository.dart';

const financeMember = CompanyMember(
  uid: 'finance-1',
  role: CompanyRole.finance,
  active: true,
  email: 'finance@example.com',
);
const managerMember = CompanyMember(
  uid: 'test-user',
  role: CompanyRole.manager,
  active: true,
);

void main() {
  test('ID undangan = companyId_sha256(email) sesuai Rules (F2)', () {
    expect(
      FirebaseCompanyRepository.invitationIdFor(
        'manager',
        'finance@example.com',
      ),
      'manager_cb358655a93d2e81ca808e35085b6cf592333428af0b979a5ac8cb844eda143d',
    );
    expect(
      FirebaseCompanyRepository.invitationIdFor('a', 'x@example.com'),
      isNot(FirebaseCompanyRepository.invitationIdFor('b', 'x@example.com')),
    );
  });

  test('Parsing member membaca status aktif/nonaktif dan gagal tertutup', () {
    final parsed = FirebaseCompanyRepository.parseMember(
      'finance-1',
      {
        'uid': 'finance-1',
        'role': 'finance',
        'status': 'inactive',
        'invitationId': 'inv',
      },
      {'inv': 'finance@example.com'},
    )!;
    expect(parsed.active, isFalse);
    expect(parsed.role, CompanyRole.finance);
    expect(parsed.email, 'finance@example.com');
    for (final broken in [
      {'uid': 'other', 'role': 'finance', 'status': 'active'},
      {'uid': 'finance-1', 'role': 'admin', 'status': 'active'},
      {'uid': 'finance-1', 'role': 'finance', 'status': 'deleted'},
    ]) {
      expect(
        FirebaseCompanyRepository.parseMember('finance-1', broken, const {}),
        isNull,
      );
    }
  });

  testWidgets('Manager menonaktifkan lalu mengaktifkan kembali Finance', (
    tester,
  ) async {
    final auth = await readyAuth();
    final repo = FakeCompanyRepository()
      ..team = const [managerMember, financeMember];
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

    expect(find.text('Anggota tim'), findsOneWidget);
    expect(find.text('finance@example.com'), findsOneWidget);
    expect(find.text('Finance · Aktif'), findsOneWidget);
    // Manager sendiri tidak ditampilkan sebagai target penonaktifan.
    expect(find.text('test-user'), findsNothing);

    final deactivate = find.widgetWithText(OutlinedButton, 'Nonaktifkan');
    await tester.ensureVisible(deactivate);
    await tester.tap(deactivate);
    await tester.pumpAndSettle();
    // Batal tidak mengubah apa pun.
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(repo.statusChanges, isEmpty);

    await tester.ensureVisible(deactivate);
    await tester.tap(deactivate);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Nonaktifkan'));
    await tester.pumpAndSettle();
    expect(repo.statusChanges, [('finance-1', false)]);
    expect(find.text('Finance · Nonaktif'), findsOneWidget);
    expect(find.text('finance@example.com dinonaktifkan.'), findsOneWidget);

    final reactivate = find.widgetWithText(FilledButton, 'Aktifkan kembali');
    await tester.ensureVisible(reactivate);
    await tester.tap(reactivate);
    await tester.pumpAndSettle();
    expect(repo.statusChanges, [('finance-1', false), ('finance-1', true)]);
    expect(find.text('Finance · Aktif'), findsOneWidget);
  });

  test('Controller menolak non-Manager dan perubahan status diri sendiri', () async {
    final auth = await readyAuth();
    final repo = FakeCompanyRepository()
      ..value = CompanyContext(
        company: testCompany.company,
        role: CompanyRole.finance,
      );
    final finance = await readyCompany(auth, repository: repo);
    expect(await finance.setMemberActive('finance-1', active: false), isFalse);

    repo.value = testCompany;
    finance.retry();
    await flushAuth();
    expect(await finance.setMemberActive(testUser.uid, active: false), isFalse);
    expect(repo.statusChanges, isEmpty);
  });

  testWidgets('Finance yang dinonaktifkan dikeluarkan ke Login dengan pesan', (
    tester,
  ) async {
    final authRepo = FakeAuthRepository(initialUser: testUser);
    final auth = await readyAuth(repository: authRepo);
    final repo = FakeCompanyRepository()
      ..value = CompanyContext(
        company: testCompany.company,
        role: CompanyRole.finance,
      );
    final company = await readyCompany(auth, repository: repo);
    final router = createAppRouter(auth: auth, company: company);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();
    expect(find.text('Finance · Anggota aktif'), findsOneWidget);

    repo.events.addError(const MembershipRevokedFailure());
    await tester.pumpAndSettle();

    expect(authRepo.signOutCalls, 1);
    expect(find.text('Selamat datang kembali.'), findsOneWidget);
    expect(
      find.text(const MembershipRevokedFailure().message),
      findsOneWidget,
    );
    expect(find.text(testCompany.company.name), findsNothing);
  });

  testWidgets('Error membership biasa tidak memaksa logout', (tester) async {
    final authRepo = FakeAuthRepository(initialUser: testUser);
    final auth = await readyAuth(repository: authRepo);
    final repo = FakeCompanyRepository();
    final company = await readyCompany(auth, repository: repo);
    final router = createAppRouter(auth: auth, company: company);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
    await tester.pumpAndSettle();
    repo.events.addError(const CompanyFailure('Koneksi terputus.'));
    await tester.pumpAndSettle();
    expect(authRepo.signOutCalls, 0);
    expect(find.text('Periksa koneksi perusahaan.'), findsOneWidget);
  });
}
