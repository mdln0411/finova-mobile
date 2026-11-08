import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/chart_account.dart';
import '../domain/chart_of_accounts_repository.dart';

class ChartOfAccountsController extends ChangeNotifier {
  ChartOfAccountsController(
    this.repository, {
    required this.companyId,
    required this.canInitialize,
  }) {
    retry();
  }
  final ChartOfAccountsRepository repository;
  final String companyId;
  final bool canInitialize;
  StreamSubscription<List<ChartAccount>>? _subscription;
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;
  bool loading = true;
  bool busy = false;
  List<ChartAccount> accounts = const [];
  String? loadError;
  String? actionError;
  String? notice;
  AccountType? filter;

  List<ChartAccount> get visibleAccounts => accounts
      .where((account) => filter == null || account.type == filter)
      .toList();

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void setFilter(AccountType? value) {
    filter = value;
    _emit();
  }

  void retry() {
    if (_disposed || busy) return;
    final generation = ++_generation;
    unawaited(_subscription?.cancel());
    _timer?.cancel();
    accounts = const [];
    loading = true;
    loadError = null;
    actionError = null;
    _emit();
    _timer = Timer(const Duration(seconds: 25), () {
      if (_disposed || generation != _generation || !loading) return;
      loading = false;
      loadError =
          'Server belum merespons. Periksa koneksi lalu muat ulang kategori.';
      _emit();
    });
    _subscription = repository
        .watchAccounts(companyId)
        .listen(
          (value) {
            if (_disposed || generation != _generation) return;
            _timer?.cancel();
            accounts = value;
            loading = false;
            loadError = null;
            _emit();
          },
          onError: (Object error) {
            if (_disposed || generation != _generation) return;
            _timer?.cancel();
            accounts = const [];
            loading = false;
            loadError = _message(error);
            _emit();
          },
        );
  }

  String _message(Object error) => error is ChartOfAccountsFailure
      ? error.message
      : 'Kategori akun belum dapat diakses. Silakan coba lagi.';

  Future<bool> initializeDefaults() async {
    if (_disposed || busy || !canInitialize || loading || loadError != null) {
      return false;
    }
    busy = true;
    actionError = null;
    notice = null;
    _emit();
    try {
      final created = await repository.initializeDefaults(companyId);
      if (_disposed) return false;
      notice = created == 0
          ? 'Kategori default sudah tersedia. Akun lama dipertahankan.'
          : '$created kategori akun default berhasil disiapkan.';
      return true;
    } catch (error) {
      if (!_disposed) actionError = _message(error);
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
    _timer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
