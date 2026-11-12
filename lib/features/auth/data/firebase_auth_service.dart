import 'package:firebase_auth/firebase_auth.dart';

import '../domain/auth_user.dart';
import 'google_sign_in_service.dart';

class FirebaseAuthService {
  FirebaseAuthService({FirebaseAuth? auth, GoogleSignInService? google})
    : _auth = auth ?? FirebaseAuth.instance,
      _google = google ?? GoogleSignInService();
  final FirebaseAuth _auth;
  final GoogleSignInService _google;
  ({String uid, String name})? _pendingRegistration;

  AuthUser? _identity(User? user) => user == null
      ? null
      : AuthUser(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
          photoUrl: user.photoURL,
        );

  Stream<AuthUser?> get authStateChanges =>
      _auth.authStateChanges().map(_identity);
  AuthUser? get currentUser => _identity(_auth.currentUser);

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> register(String name, String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    _pendingRegistration = (uid: credential.user!.uid, name: name);
    await completeRegistration();
  }

  Future<void> completeRegistration() async {
    final pending = _pendingRegistration;
    if (pending != null && _auth.currentUser?.uid == pending.uid) {
      await _auth.currentUser!.updateDisplayName(pending.name);
      _pendingRegistration = null;
    }
  }

  Future<void> signInWithGoogle() async {
    final token = await _google.authenticate();
    await _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: token),
    );
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<void> signOut() async {
    // Firebase adalah sumber sesi; kegagalan cleanup Google tidak menahan sesi Firebase.
    final usedGoogle =
        _auth.currentUser?.providerData.any(
          (provider) => provider.providerId == 'google.com',
        ) ??
        false;
    await _auth.signOut();
    _pendingRegistration = null;
    await _google.signOut(initialize: usedGoogle);
  }
}
