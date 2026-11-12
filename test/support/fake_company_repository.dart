import 'dart:async';

import 'package:finova/features/company/application/company_controller.dart';
import 'package:finova/features/company/domain/company.dart';
import 'package:finova/features/company/domain/company_repository.dart';
import 'package:finova/features/auth/application/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_repository.dart';

final testCompany = CompanyContext(
  company: Company(
    id: 'company-1',
    name: 'CV Finova Sejahtera',
    businessType: 'Jasa',
    bookkeepingStartDate: DateTime.utc(2026, 1, 1),
    createdBy: testUser.uid,
  ),
  role: CompanyRole.manager,
);

class FakeCompanyRepository implements CompanyRepository {
  FakeCompanyRepository({bool hasCompany = true})
    : value = hasCompany ? testCompany : null;
  CompanyContext? value;
  CompanyFailure? failure;
  Completer<void>? delay;
  int createCalls = 0;
  int invitationCalls = 0;
  int respondCalls = 0;
  bool verified = true;
  CompanyDraft? savedDraft;
  final events = StreamController<CompanyContext?>.broadcast();
  List<CompanyInvitation> pending = const [];
  @override
  Stream<CompanyContext?> watchMembership(String uid) async* {
    if (delay != null) await delay!.future;
    if (failure != null) throw failure!;
    yield value;
    yield* events.stream;
  }

  @override
  Future<void> createCompany(CompanyDraft draft) async {
    createCalls++;
    if (delay != null) await delay!.future;
    if (failure != null) throw failure!;
    savedDraft = draft;
    value ??= testCompany;
  }

  @override
  Future<List<CompanyInvitation>> invitations({String? companyId}) async {
    invitationCalls++;
    if (failure != null) throw failure!;
    return pending;
  }

  @override
  Future<void> inviteFinance(String companyId, String email) async {
    if (failure != null) throw failure!;
    pending = [
      CompanyInvitation(
        id: 'invite',
        companyId: companyId,
        companyName: testCompany.company.name,
        email: email,
        status: 'pending',
      ),
    ];
  }

  String? savedLogo;
  @override
  Future<void> updateLogo(String companyId, String? logoSvg) async {
    if (failure != null) throw failure!;
    savedLogo = logoSvg;
  }

  @override
  Future<void> cancelInvitation(String invitationId) async {
    pending = [];
  }

  @override
  Future<void> respondToInvitation(
    String invitationId, {
    required bool accept,
  }) async {
    respondCalls++;
    if (failure != null) throw failure!;
    if (!verified) throw const CompanyFailure('Verifikasi email dahulu.');
    if (accept) {
      value = CompanyContext(
        company: testCompany.company,
        role: CompanyRole.finance,
      );
    }
    pending = [];
  }

  @override
  Future<bool> refreshVerifiedEmail() async => verified;
  @override
  Future<void> sendVerificationEmail() async {}
  Future<void> dispose() => events.close();
}

Future<CompanyController> readyCompany(
  AuthController auth, {
  FakeCompanyRepository? repository,
}) async {
  final repo = repository ?? FakeCompanyRepository();
  final company = CompanyController(auth, repo);
  addTearDown(() async {
    company.dispose();
    await repo.dispose();
  });
  await flushAuth();
  return company;
}
