import 'fake_company_repository.dart';
import 'fake_chart_of_accounts_repository.dart';
import 'fake_transactions_repository.dart';
import 'fake_ledger_repository.dart';
import 'fake_receivables_repository.dart';

import 'dart:async';

import 'package:finova/app/app.dart';
import 'package:finova/features/auth/application/auth_controller.dart';
import 'package:finova/features/auth/domain/auth_failure.dart';
import 'package:finova/features/auth/domain/auth_repository.dart';
import 'package:finova/features/auth/domain/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

const testUser = AuthUser(
  uid: 'test-user',
  email: 'andi@example.com',
  displayName: 'Andi',
);

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthUser? initialUser, this.emitInitial = true})
    : _current = initialUser;
  AuthUser? _current;
  final bool emitInitial;
  final _events = StreamController<AuthUser?>.broadcast();
  int signInCalls = 0;
  int registerCalls = 0;
  int googleCalls = 0;
  int resetCalls = 0;
  int signOutCalls = 0;
  int profileCalls = 0;
  Object? actionError;
  Object? profileError;
  Completer<void>? actionDelay;
  Completer<void>? profileDelay;
  String? lastPassword;
  bool profileCompleted = true;
  String? savedName;
  String? savedPhone;
  int completeProfileCalls = 0;

  @override
  Future<UserProfile> completeProfile(String name, String? phoneNumber) async {
    completeProfileCalls++;
    await _action();
    profileCompleted = true;
    savedName = name.trim();
    savedPhone = phoneNumber;
    return UserProfile(
      uid: _current!.uid,
      displayName: savedName!,
      email: _current!.email,
      phoneNumber: phoneNumber,
      profileCompleted: true,
    );
  }

  @override
  AuthUser? get currentUser => _current;
  @override
  Stream<AuthUser?> get authStateChanges async* {
    if (emitInitial) yield _current;
    yield* _events.stream;
  }

  void emit(AuthUser? value) {
    _current = value;
    _events.add(value);
  }

  Future<void> _action() async {
    if (actionDelay != null) await actionDelay!.future;
    if (actionError != null) throw actionError!;
  }

  @override
  Future<void> signIn(String email, String password) async {
    signInCalls++;
    lastPassword = password;
    await _action();
    emit(testUser);
  }

  @override
  Future<void> register(String name, String email, String password) async {
    registerCalls++;
    lastPassword = password;
    await _action();
    profileCompleted = false;
    emit(AuthUser(uid: testUser.uid, email: email, displayName: name));
  }

  @override
  Future<void> signInWithGoogle() async {
    googleCalls++;
    await _action();
    emit(testUser);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    resetCalls++;
    await _action();
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    await _action();
    emit(null);
  }

  @override
  Future<UserProfile> ensureProfile(AuthUser user) async {
    profileCalls++;
    if (profileDelay != null) await profileDelay!.future;
    if (profileError != null) throw profileError!;
    return UserProfile(
      uid: user.uid,
      displayName: savedName ?? user.displayName ?? 'Pengguna Finova',
      email: user.email,
      photoUrl: user.photoUrl,
      phoneNumber: savedPhone,
      profileCompleted: profileCompleted,
    );
  }

  void failStream() =>
      _events.addError(const AuthFailure('stream unavailable'));
  Future<void> dispose() => _events.close();
}

Future<void> flushAuth() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.value();
  }
}

Future<AuthController> readyAuth({FakeAuthRepository? repository}) async {
  final repo = repository ?? FakeAuthRepository(initialUser: testUser);
  final auth = AuthController(repo);
  addTearDown(() async {
    auth.dispose();
    await repo.dispose();
  });
  await flushAuth();
  return auth;
}

Future<FinovaApp> authenticatedApp() async {
  final receivables = FakeReceivablesRepository();
  addTearDown(receivables.dispose);
  return FinovaApp(
    authController: await readyAuth(),
    companyRepository: FakeCompanyRepository(),
    chartRepository: FakeChartOfAccountsRepository(),
    transactionsRepository: FakeTransactionsRepository(),
    ledgerRepository: FakeLedgerRepository(),
    receivablesRepository: receivables,
  );
}
