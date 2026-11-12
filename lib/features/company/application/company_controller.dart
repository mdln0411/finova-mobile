import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../auth/application/auth_controller.dart';
import '../domain/company.dart';
import '../domain/company_repository.dart';

enum CompanyPhase { waiting, loading, noCompany, active, error }

/// Status perusahaan hanya berasal dari membership server, bukan pilihan role UI.
class CompanyController extends ChangeNotifier {
  CompanyController(this.auth, this._repository) {
    auth.addListener(_onAuth);
    _onAuth();
  }
  final AuthController auth;
  final CompanyRepository _repository;
  StreamSubscription<CompanyContext?>? _subscription;
  String? _uid;
  int _generation = 0;
  bool _disposed = false;
  CompanyPhase phase = CompanyPhase.waiting;
  CompanyContext? context;
  bool busy = false;
  String? message;
  List<CompanyInvitation> pendingInvitations = const [];
  bool emailVerified = false;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _onAuth() {
    final uid = auth.phase == AuthPhase.signedIn ? auth.user?.uid : null;
    if (uid == _uid) return;
    _uid = uid;
    _generation++;
    unawaited(_subscription?.cancel());
    _subscription = null;
    context = null;
    message = null;
    pendingInvitations = const [];
    emailVerified = false;
    busy = false;
    if (uid == null) {
      phase = CompanyPhase.waiting;
      _emit();
    } else {
      retry();
    }
  }

  void retry() {
    final uid = _uid;
    if (uid == null || _disposed || busy) return;
    final generation = ++_generation;
    unawaited(_subscription?.cancel());
    context = null;
    phase = CompanyPhase.loading;
    message = null;
    _emit();
    _subscription = _repository
        .watchMembership(uid)
        .listen(
          (value) {
            if (_disposed || generation != _generation) return;
            context = value;
            phase = value == null
                ? CompanyPhase.noCompany
                : CompanyPhase.active;
            _emit();
          },
          onError: (Object error) {
            if (_disposed || generation != _generation) return;
            context = null;
            phase = CompanyPhase.error;
            message = _error(error);
            _emit();
          },
        );
  }

  String _error(Object error) => error is CompanyFailure
      ? error.message
      : 'Perusahaan belum dapat diakses. Periksa koneksi dan coba lagi.';

  Future<bool> _action(Future<void> Function() operation) async {
    if (busy || _disposed || _uid == null) return false;
    final uid = _uid;
    final generation = _generation;
    busy = true;
    message = null;
    _emit();
    try {
      await operation();
      return !_disposed && uid == _uid && generation == _generation;
    } catch (error) {
      if (!_disposed && uid == _uid && generation == _generation) {
        message = _error(error);
      }
      return false;
    } finally {
      if (!_disposed && uid == _uid && generation == _generation) {
        busy = false;
        _emit();
      }
    }
  }

  Future<bool> createCompany(CompanyDraft draft) async {
    if (phase != CompanyPhase.noCompany) return false;
    final error = draft.validate();
    if (error != null) {
      message = error;
      _emit();
      return false;
    }
    final success = await _action(() => _repository.createCompany(draft));
    if (success) retry();
    return success;
  }

  /// Pemeriksaan role di sini hanya UX; Rules menolak non-Manager.
  Future<bool> updateLogo(String? logoSvg) async {
    final current = context;
    if (current?.role != CompanyRole.manager) return false;
    final error = CompanyValidators.logoSvg(logoSvg);
    if (error != null) {
      message = error;
      _emit();
      return false;
    }
    return _action(() => _repository.updateLogo(current!.company.id, logoSvg));
  }

  Future<bool> loadInvitations() => _action(() async {
    final uid = _uid;
    final generation = _generation;
    final companyId = context?.company.id;
    final verified = await _repository.refreshVerifiedEmail();
    final invitations = companyId == null && !verified
        ? <CompanyInvitation>[]
        : await _repository.invitations(companyId: companyId);
    if (_uid != uid || generation != _generation || _disposed) return;
    emailVerified = verified;
    pendingInvitations = invitations;
  });

  Future<bool> sendVerificationEmail() =>
      _action(_repository.sendVerificationEmail);

  Future<bool> inviteFinance(String email) async {
    final current = context;
    if (current?.role != CompanyRole.manager) return false;
    final success = await _action(
      () => _repository.inviteFinance(current!.company.id, email),
    );
    if (success) await loadInvitations();
    return success;
  }

  Future<bool> cancelInvitation(String id) async {
    if (context?.role != CompanyRole.manager) return false;
    final success = await _action(() => _repository.cancelInvitation(id));
    if (success) await loadInvitations();
    return success;
  }

  Future<bool> respond(String id, {required bool accept}) async {
    if (phase != CompanyPhase.noCompany) return false;
    final success = await _action(
      () => _repository.respondToInvitation(id, accept: accept),
    );
    if (success) {
      if (accept) {
        retry();
      } else {
        await loadInvitations();
      }
    }
    return success;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    auth.removeListener(_onAuth);
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
