import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../company/domain/company.dart';
import '../domain/finance_transaction.dart';
import '../domain/transactions_repository.dart';

/// Daftar transaksi perusahaan + aksi pembuat dan Manager.
/// Pemeriksaan peran di sini hanya untuk UX; Rules adalah pengaman utama.
class TransactionsController extends ChangeNotifier {
  TransactionsController(
    this.repository, {
    required this.companyId,
    required this.userId,
    required this.role,
  }) {
    retry();
  }
  final TransactionsRepository repository;
  final String companyId;
  final String? userId;
  final CompanyRole role;
  StreamSubscription<List<FinanceTransaction>>? _subscription;
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;
  bool loading = true;
  bool busy = false;
  List<FinanceTransaction> transactions = const [];
  TransactionStatus? filter;
  String? loadError;
  String? actionError;
  String? notice;

  bool get isManager => role == CompanyRole.manager;

  List<FinanceTransaction> get visibleTransactions => transactions
      .where((tx) => filter == null || tx.status == filter)
      .toList();

  List<FinanceTransaction> get pendingTransactions =>
      transactions.where((tx) => tx.isPending).toList();

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void setFilter(TransactionStatus? value) {
    filter = value;
    _emit();
  }

  void clearMessages() {
    actionError = null;
    notice = null;
    _emit();
  }

  void retry() {
    if (_disposed || busy) return;
    final generation = ++_generation;
    unawaited(_subscription?.cancel());
    _timer?.cancel();
    transactions = const [];
    loading = true;
    loadError = null;
    _emit();
    _timer = Timer(const Duration(seconds: 25), () {
      if (_disposed || generation != _generation || !loading) return;
      loading = false;
      loadError =
          'Server belum merespons. Periksa koneksi lalu muat ulang transaksi.';
      _emit();
    });
    _subscription = repository
        .watchTransactions(companyId)
        .listen(
          (value) {
            if (_disposed || generation != _generation) return;
            _timer?.cancel();
            transactions = value;
            loading = false;
            loadError = null;
            _emit();
          },
          onError: (Object error) {
            if (_disposed || generation != _generation) return;
            _timer?.cancel();
            transactions = const [];
            loading = false;
            loadError = _message(error);
            _emit();
          },
        );
  }

  String _message(Object error) => error is TransactionFailure
      ? error.message
      : 'Transaksi belum dapat diakses. Silakan coba lagi.';

  String newTransactionId() => repository.newTransactionId(companyId);

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

  Future<bool> create(String id, TransactionDraft draft) => _run(
    () => repository.create(companyId, id, draft),
    'Transaksi diajukan dan menunggu persetujuan Manager.',
  );

  Future<bool> update(FinanceTransaction tx, TransactionDraft draft) {
    if (!tx.canModify(userId)) return _denied();
    return _run(
      () => repository.update(companyId, tx.id, draft),
      'Transaksi diperbarui.',
    );
  }

  Future<bool> delete(FinanceTransaction tx) {
    if (!tx.canModify(userId)) return _denied();
    return _run(
      () => repository.delete(companyId, tx.id),
      'Transaksi dihapus.',
    );
  }

  Future<bool> approve(FinanceTransaction tx) {
    if (!isManager || !tx.isPending) return _denied();
    return _run(
      () => repository.approve(companyId, tx.id),
      'Transaksi disetujui.',
    );
  }

  Future<bool> reject(FinanceTransaction tx, String reason) {
    if (!isManager || !tx.isPending) return _denied();
    final error = validateRejectReason(reason);
    if (error != null) {
      actionError = error;
      _emit();
      return Future.value(false);
    }
    return _run(
      () => repository.reject(companyId, tx.id, reason.trim()),
      'Transaksi ditolak.',
    );
  }

  Future<bool> _denied() {
    actionError = 'Aksi tidak diizinkan untuk transaksi ini.';
    _emit();
    return Future.value(false);
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
