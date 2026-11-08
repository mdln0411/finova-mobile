import 'auth_user.dart';

abstract interface class AuthRepository {
  Stream<AuthUser?> get authStateChanges;
  AuthUser? get currentUser;
  Future<void> signIn(String email, String password);
  Future<void> register(String name, String email, String password);
  Future<void> signInWithGoogle();
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
  Future<UserProfile> ensureProfile(AuthUser user);
  Future<UserProfile> completeProfile(String name, String? phoneNumber);
}
