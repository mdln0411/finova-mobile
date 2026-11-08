import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/auth_failure.dart';

String authErrorMessage(Object error) {
  if (error is AuthFailure) return error.message;
  if (error is GoogleSignInException) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled => 'Login Google dibatalkan.',
      GoogleSignInExceptionCode.clientConfigurationError ||
      GoogleSignInExceptionCode.providerConfigurationError => 'Google Sign-In belum dikonfigurasi dengan benar. Hubungi pengelola aplikasi.',
      GoogleSignInExceptionCode.interrupted =>
        'Login Google terhenti. Silakan coba lagi.',
      _ => 'Tidak dapat masuk dengan Google. Periksa koneksi lalu coba lagi.',
    };
  }
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-email' => 'Alamat email tidak valid.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'Email atau password tidak sesuai.',
      'user-disabled' =>
        'Akun ini tidak dapat digunakan. Hubungi pengelola aplikasi.',
      'email-already-in-use' => 'Pendaftaran tidak dapat diselesaikan. Coba masuk atau gunakan email lain.',
      'weak-password' || 'password-does-not-meet-requirements' => 'Password belum memenuhi kebijakan keamanan. Gunakan password yang lebih kuat.',
      'too-many-requests' =>
        'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.',
      'network-request-failed' =>
        'Koneksi bermasalah. Periksa internet lalu coba lagi.',
      'operation-not-allowed' =>
        'Metode login ini belum tersedia. Hubungi pengelola aplikasi.',
      'account-exists-with-different-credential' =>
        'Gunakan metode login yang sebelumnya Anda gunakan untuk akun ini.',
      _ => 'Autentikasi belum berhasil. Silakan coba lagi.',
    };
  }
  if (error is FirebaseException && error.plugin == 'cloud_firestore') {
    return error.code == 'permission-denied'
        ? 'Profil belum dapat diakses. Hubungi pengelola untuk memeriksa izin profil.'
        : 'Profil belum dapat disinkronkan. Periksa koneksi dan coba lagi.';
  }
  return 'Terjadi kendala. Periksa koneksi Anda lalu coba lagi.';
}
