import 'package:google_sign_in/google_sign_in.dart';

import '../domain/auth_failure.dart';

class GoogleSignInService {
  GoogleSignInService({GoogleSignIn? google})
    : _google = google ?? GoogleSignIn.instance;
  final GoogleSignIn _google;
  Future<void>? _initialization;

  Future<void> _initialize() async {
    try {
      await (_initialization ??= _google.initialize());
    } catch (_) {
      // Kegagalan konfigurasi dapat dicoba ulang, bukan menyimpan Future gagal.
      _initialization = null;
      rethrow;
    }
  }

  Future<String> authenticate() async {
    await _initialize();
    if (!_google.supportsAuthenticate()) {
      throw const AuthFailure('Login Google tersedia pada aplikasi Android.');
    }
    final account = await _google.authenticate();
    final token = account.authentication.idToken;
    if (token == null || token.isEmpty) {
      throw const AuthFailure(
        'Google tidak mengirimkan identitas akun. Silakan coba lagi.',
      );
    }
    return token;
  }

  Future<void> signOut({bool initialize = false}) async {
    if (initialize || _initialization != null) {
      await _initialize();
      await _google.signOut();
    }
  }
}
