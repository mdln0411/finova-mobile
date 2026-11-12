import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/auth_failure.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

enum AuthPhase {
  loading,
  signedOut,
  profileIncomplete,
  signedIn,
  profileError,
  sessionError,
}

/// Satu pemilik sesi. Tidak menyimpan password/token, role, atau flag login lokal.
class AuthController extends ChangeNotifier {
  AuthController(this._repository) {
    _subscription = _repository.authStateChanges.listen(
      _onAuthChanged,
      onError: (Object error) {
        _generation++;
        phase = AuthPhase.sessionError;
        sessionMessage = 'Sesi belum dapat diperiksa. Silakan coba lagi.';
        _emit();
      },
    );
  }
  final AuthRepository _repository;
  late final StreamSubscription<AuthUser?> _subscription;
  AuthPhase phase = AuthPhase.loading;
  AuthUser? user;
  UserProfile? profile;
  bool busy = false;
  String? actionMessage;
  String? sessionMessage;
  bool _commandActive = false;
  bool _disposed = false;
  int _generation = 0;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _onAuthChanged(AuthUser? value) {
    if (_commandActive) return;
    // Event yang sama dapat tiba setelah Future login selesai. Jangan mulai
    // sinkronisasi kedua atau menampilkan loading ulang untuk sesi yang sama.
    if (value == null && phase == AuthPhase.signedOut) return;
    if (value != null &&
        value.uid == user?.uid &&
        phase != AuthPhase.signedOut &&
        phase != AuthPhase.sessionError) {
      return;
    }
    unawaited(_resolve(value));
  }

  Future<void> _resolve(AuthUser? value) async {
    if (_disposed) return;
    final generation = ++_generation;
    user = value;
    profile = null;
    sessionMessage = null;
    if (value == null) {
      phase = AuthPhase.signedOut;
      _emit();
      return;
    }
    phase = AuthPhase.loading;
    _emit();
    try {
      final loaded = await _repository.ensureProfile(value);
      if (_disposed || generation != _generation) return;
      profile = loaded;
      phase = loaded.profileCompleted
          ? AuthPhase.signedIn
          : AuthPhase.profileIncomplete;
    } catch (error) {
      if (_disposed || generation != _generation) return;
      phase = AuthPhase.profileError;
      sessionMessage = _message(
        error,
        'Profil belum dapat disinkronkan. Periksa koneksi Anda dan coba lagi.',
      );
    }
    _emit();
  }

  String _message(Object error, String fallback) =>
      error is AuthFailure ? error.message : fallback;

  Future<bool> _authenticate(Future<void> Function() action) async {
    if (busy || _disposed) return false;
    busy = true;
    actionMessage = null;
    _commandActive = true;
    // Membatalkan hasil sinkronisasi sesi lama yang mungkin masih berjalan.
    _generation++;
    _emit();
    var succeeded = true;
    try {
      await action();
    } catch (error) {
      succeeded = false;
      actionMessage = _message(
        error,
        'Autentikasi belum berhasil. Silakan coba lagi.',
      );
    } finally {
      _commandActive = false;
      if (!_disposed) {
        // currentUser juga berasal dari Firebase. Membaca ulang setelah update
        // displayName selesai, sebab authStateChanges dapat datang lebih awal.
        await _resolve(_repository.currentUser);
        busy = false;
        _emit();
      }
    }
    return succeeded;
  }

  Future<bool> signIn(String email, String password) =>
      _authenticate(() => _repository.signIn(email, password));
  Future<bool> register(String name, String email, String password) =>
      _authenticate(() => _repository.register(name, email, password));
  Future<bool> signInWithGoogle() =>
      _authenticate(_repository.signInWithGoogle);
  /// [notice] ditampilkan di halaman Login setelah keluar, mis. akses dicabut.
  Future<bool> signOut({String? notice}) async {
    final success = await _authenticate(_repository.signOut);
    if (success && notice != null && !_disposed) {
      actionMessage = notice;
      _emit();
    }
    return success;
  }

  Future<bool> sendPasswordReset(String email) async {
    if (busy || _disposed) return false;
    busy = true;
    actionMessage = null;
    _emit();
    try {
      await _repository.sendPasswordReset(email);
      return true;
    } catch (error) {
      actionMessage = _message(
        error,
        'Permintaan belum terkirim. Silakan coba lagi.',
      );
      return false;
    } finally {
      busy = false;
      _emit();
    }
  }

  Future<void> retrySession() async {
    if (busy || _disposed) return;
    busy = true;
    _emit();
    try {
      await _resolve(_repository.currentUser);
    } finally {
      busy = false;
      _emit();
    }
  }

  void clearActionMessage() {
    actionMessage = null;
    _emit();
  }

  Future<bool> completeProfile(String name, String? phoneNumber) async {
    final current = user;
    if (busy || _disposed || current == null) return false;
    busy = true;
    actionMessage = null;
    final generation = ++_generation;
    _emit();
    try {
      final saved = await _repository.completeProfile(name, phoneNumber);
      if (_disposed || generation != _generation || user?.uid != current.uid) {
        return false;
      }
      profile = saved;
      phase = saved.profileCompleted
          ? AuthPhase.signedIn
          : AuthPhase.profileIncomplete;
      return saved.profileCompleted;
    } catch (error) {
      if (!_disposed && generation == _generation) {
        actionMessage = _message(
          error,
          'Profil belum tersimpan. Silakan coba lagi.',
        );
      }
      return false;
    } finally {
      busy = false;
      _emit();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
