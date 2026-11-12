import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../chart_of_accounts/domain/chart_account.dart';
import '../../transactions/domain/finance_transaction.dart';
import '../domain/ledger_calculator.dart';
import '../domain/ledger_repository.dart';

/// Memuat transaksi `approved` dan menghitung ledger/saldo di memori.
class LedgerController extends ChangeNotifier {
  LedgerController(this.repository, {required this.companyId}) {
    retry();
  }
  final LedgerRepository repository;
  final String companyId;
  StreamSubscription<List<FinanceTransaction>>? _subscription;
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;
  bool loading = true;
  List<FinanceTransaction> transactions = const [];
  String? loadError;
  String? selectedAccountCode;
  DateTime? from;
  DateTime? to;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void selectAccount(String? code) {
    selectedAccountCode = code;
    _emit();
  }

  void setRange(DateTime? start, DateTime? end) {
    from = start == null ? null : dateOnly(start);
    to = end == null ? null : dateOnly(end);
    _emit();
  }

  /// Ledger akun terpilih, atau null jika akun belum dipilih/tidak ditemukan.
  AccountLedger? ledgerFor(List<ChartAccount> accounts) {
    final account = accounts
        .where((a) => a.code == selectedAccountCode)
        .firstOrNull;
    if (account == null) return null;
    return LedgerCalculator.forAccount(
      account,
      transactions,
      from: from,
      to: to,
    );
  }

  Map<String, int> balancesFor(List<ChartAccount> accounts) =>
      LedgerCalculator.balances(accounts, transactions);

  void retry() {
    if (_disposed) return;
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
          'Server belum merespons. Periksa koneksi lalu muat ulang buku besar.';
      _emit();
    });
    _subscription = repository
        .watchApprovedTransactions(companyId)
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
            loadError = error is TransactionFailure
                ? error.message
                : 'Buku besar belum dapat diakses. Silakan coba lagi.';
            _emit();
          },
        );
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
