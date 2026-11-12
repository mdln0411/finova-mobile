import 'package:firebase_auth/firebase_auth.dart';

import '../domain/auth_failure.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';
import 'auth_error_message.dart';
import 'firebase_auth_service.dart';
import 'user_profile_service.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuthService? auth,
    UserProfileService? profiles,
  }) : _auth = auth ?? FirebaseAuthService(),
       _profiles = profiles ?? UserProfileService();
  final FirebaseAuthService _auth;
  final UserProfileService _profiles;

  @override
  Stream<AuthUser?> get authStateChanges => _auth.authStateChanges;
  @override
  AuthUser? get currentUser => _auth.currentUser;

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      throw AuthFailure(authErrorMessage(error));
    }
  }

  @override
  Future<void> signIn(String email, String password) =>
      _guard(() => _auth.signIn(email.trim(), password));
  @override
  Future<void> register(String name, String email, String password) =>
      _guard(() => _auth.register(name.trim(), email.trim(), password));
  @override
  Future<void> signInWithGoogle() => _guard(_auth.signInWithGoogle);
  @override
  Future<void> signOut() => _guard(_auth.signOut);

  @override
  Future<void> sendPasswordReset(String email) => _guard(() async {
    try {
      await _auth.sendPasswordReset(email.trim());
    } on FirebaseAuthException catch (error) {
      // Respons sama untuk email yang terdaftar maupun tidak terdaftar.
      if (!['user-not-found', 'user-disabled'].contains(error.code)) rethrow;
    }
  });

  @override
  Future<UserProfile> ensureProfile(AuthUser user) async {
    try {
      await _auth.completeRegistration();
      final current = _auth.currentUser;
      if (current == null || current.uid != user.uid) {
        throw const AuthFailure('Sesi berubah. Silakan masuk kembali.');
      }
      return await _profiles.ensureProfile(current);
    } on AuthFailure {
      rethrow;
    } catch (error) {
      throw AuthFailure(authErrorMessage(error));
    }
  }

  @override
  Future<UserProfile> completeProfile(String name, String? phoneNumber) async {
    try {
      final current = _auth.currentUser;
      if (current == null) {
        throw const AuthFailure('Sesi berakhir. Silakan masuk kembali.');
      }
      return await _profiles.completeProfile(current, name, phoneNumber);
    } on AuthFailure {
      rethrow;
    } catch (error) {
      throw AuthFailure(authErrorMessage(error));
    }
  }
}
