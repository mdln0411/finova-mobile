import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../company/domain/company.dart';
import '../../transactions/domain/finance_transaction.dart';
import '../domain/bill.dart';
import '../domain/receivable.dart';
import '../domain/receivables_repository.dart';

class ReceivablesController extends ChangeNotifier {
  ReceivablesController(
    this.repository, {
    required this.companyId,
    required this.userId,
    required this.role,
  }) {
    retry();
  }

  final ReceivablesRepository repository;
  final String companyId;
  final String? userId;
  final CompanyRole role;
  StreamSubscription<List<Receivable>>? _subscription;
  StreamSubscription<List<Bill>>? _billSubscription;
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;
  bool _receivablesLoaded = false;
  bool _billsLoaded = false;
  String? _receivablesError;
  String? _billsError;
  bool loading = true;
  bool busy = false;
  List<Receivable> receivables = const [];
  List<Bill> bills = const [];
  String? loadError;
  String? actionError;
  String? notice;

  bool get isManager => role == CompanyRole.manager;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  String newReceivableId() => repository.newReceivableId(companyId);

  void retry() {
    if (_disposed || busy) return;
    final generation = ++_generation;
    unawaited(_subscription?.cancel());
    unawaited(_billSubscription?.cancel());
    _timer?.cancel();
    receivables = const [];
    bills = const [];
    _receivablesLoaded = false;
    _billsLoaded = false;
    _receivablesError = null;
    _billsError = null;
    loading = true;
    loadError = null;
    _emit();
    _timer = Timer(const Duration(seconds: 25), () {
      if (_disposed || generation != _generation || !loading) return;
      loading = false;
      loadError =
          'Server belum merespons. Periksa koneksi lalu muat ulang piutang.';
      _emit();
    });
    _subscription = repository
        .watchReceivables(companyId)
        .listen(
          (value) {
            if (_disposed || generation != _generation) return;
            receivables = value;
            _receivablesLoaded = true;
            _receivablesError = null;
            _updateLoadState();
            _emit();
          },
          onError: (Object error) {
            if (_disposed || generation != _generation) return;
            receivables = const [];
            _receivablesLoaded = true;
            _receivablesError = _message(error);
            _updateLoadState();
            _emit();
          },
        );
    _billSubscription = repository
        .watchBills(companyId)
        .listen(
          (value) {
            if (_disposed || generation != _generation) return;
            bills = value;
            _billsLoaded = true;
            _billsError = null;
            _updateLoadState();
            _emit();
          },
          onError: (Object error) {
            if (_disposed || generation != _generation) return;
            bills = const [];
            _billsLoaded = true;
            _billsError = _message(error);
            _updateLoadState();
            _emit();
          },
        );
  }

  void _updateLoadState() {
    loading = !_receivablesLoaded || !_billsLoaded;
    if (!loading) {
      _timer?.cancel();
      loadError = _receivablesError ?? _billsError;
    }
  }

  String _message(Object error) => error is ReceivableFailure
      ? error.message
      : 'Piutang belum dapat diakses. Silakan coba lagi.';

  void clearMessages() {
    actionError = null;
    notice = null;
    _emit();
  }

  Future<bool> _run(Future<void> Function() action, String success) async {
    if (_disposed || busy) return false;
    busy = true;
    actionError = null;
    notice = null;
    _emit();
    try {
      await action();
      if (!_disposed) notice = success;
      return true;
    } catch (error) {
      if (!_disposed) actionError = _message(error);
      return false;
    } finally {
      busy = false;
      _emit();
    }
  }

  Future<bool> create(String id, ReceivableDraft draft) => _run(
    () => repository.create(companyId, id, draft),
    'Piutang diajukan dan menunggu persetujuan Manager.',
  );

  Future<bool> update(Receivable receivable, ReceivableDraft draft) {
    if (!receivable.canModify(userId)) return _denied();
    return _run(
      () => repository.update(companyId, receivable.id, draft),
      'Piutang diperbarui.',
    );
  }

  Future<bool> delete(Receivable receivable) {
    if (!receivable.canModify(userId)) return _denied();
    return _run(
      () => repository.delete(companyId, receivable.id),
      'Piutang dihapus.',
    );
  }

  Future<bool> approve(Receivable receivable) {
    if (!isManager || !receivable.isPending) return _denied();
    return _run(
      () => repository.approve(companyId, receivable.id),
      'Piutang disetujui.',
    );
  }

  Future<bool> reject(Receivable receivable, String reason) {
    if (!isManager || !receivable.isPending) return _denied();
    final error = validateRejectReason(reason);
    if (error != null) {
      actionError = error;
      _emit();
      return Future.value(false);
    }
    return _run(
      () => repository.reject(companyId, receivable.id, reason.trim()),
      'Piutang ditolak.',
    );
  }

  Future<bool> _denied() {
    actionError = 'Aksi tidak diizinkan untuk piutang ini.';
    _emit();
    return Future.value(false);
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(_billSubscription?.cancel());
    super.dispose();
  }
}
