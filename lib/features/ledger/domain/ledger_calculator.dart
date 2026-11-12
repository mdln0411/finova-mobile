import '../../chart_of_accounts/domain/chart_account.dart';
import '../../transactions/domain/finance_transaction.dart';

/// Satu baris buku besar. Nominal integer Rupiah.
class LedgerEntry {
  const LedgerEntry({
    required this.transactionId,
    required this.date,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
  });
  final String transactionId;
  final DateTime date;
  final String description;
  final int debit;
  final int credit;

  /// Saldo berjalan setelah baris ini, mengikuti saldo normal akun.
  final int balance;
}

/// Buku besar satu akun pada rentang tanggal tertentu.
class AccountLedger {
  const AccountLedger({
    required this.account,
    required this.openingBalance,
    required this.entries,
  });
  final ChartAccount account;

  /// Saldo dari transaksi sebelum awal rentang (0 tanpa filter awal).
  final int openingBalance;
  final List<LedgerEntry> entries;

  int get totalDebit => entries.fold(0, (sum, e) => sum + e.debit);
  int get totalCredit => entries.fold(0, (sum, e) => sum + e.credit);
  int get closingBalance =>
      entries.isEmpty ? openingBalance : entries.last.balance;
}

/// Menghitung ledger dari transaksi tanpa menyimpannya (pure Dart).
/// Hanya transaksi `approved` yang diproses; status lain diabaikan.
///
/// Double-entry:
/// - income : debit akun Kas/Bank, kredit akun Pendapatan.
/// - expense: debit akun Beban, kredit akun Kas/Bank.
abstract final class LedgerCalculator {
  /// Sisi debit dan kredit sebuah transaksi.
  static ({String debit, String credit}) postingOf(FinanceTransaction tx) =>
      switch (tx.type) {
        TransactionType.income => (
          debit: tx.cashAccountId,
          credit: tx.categoryAccountId,
        ),
        TransactionType.expense => (
          debit: tx.categoryAccountId,
          credit: tx.cashAccountId,
        ),
      };

  /// Perubahan saldo akun oleh satu sisi posting, mengikuti saldo normal.
  static int signedAmount(
    ChartAccount account, {
    int debit = 0,
    int credit = 0,
  }) => account.type.normalBalance == BalanceSide.debit
      ? debit - credit
      : credit - debit;

  static List<FinanceTransaction> _approvedSorted(
    Iterable<FinanceTransaction> transactions,
  ) {
    final items = transactions
        .where((tx) => tx.status == TransactionStatus.approved)
        .toList();
    // Kronologis dan deterministik agar saldo berjalan stabil.
    items.sort((a, b) {
      final byDate = dateOnly(a.date).compareTo(dateOnly(b.date));
      if (byDate != 0) return byDate;
      final byCreated = a.createdAt.compareTo(b.createdAt);
      return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
    });
    return items;
  }

  /// Ledger satu akun. [from] dan [to] inklusif (per tanggal).
  static AccountLedger forAccount(
    ChartAccount account,
    Iterable<FinanceTransaction> transactions, {
    DateTime? from,
    DateTime? to,
  }) {
    final start = from == null ? null : dateOnly(from);
    final end = to == null ? null : dateOnly(to);
    var opening = 0;
    var balance = 0;
    final entries = <LedgerEntry>[];
    for (final tx in _approvedSorted(transactions)) {
      final posting = postingOf(tx);
      final debit = posting.debit == account.code ? tx.amount : 0;
      final credit = posting.credit == account.code ? tx.amount : 0;
      if (debit == 0 && credit == 0) continue;
      final day = dateOnly(tx.date);
      if (end != null && day.isAfter(end)) break;
      final delta = signedAmount(account, debit: debit, credit: credit);
      if (start != null && day.isBefore(start)) {
        opening += delta;
        balance = opening;
        continue;
      }
      balance += delta;
      entries.add(
        LedgerEntry(
          transactionId: tx.id,
          date: day,
          description: tx.description,
          debit: debit,
          credit: credit,
          balance: balance,
        ),
      );
    }
    return AccountLedger(
      account: account,
      openingBalance: opening,
      entries: List.unmodifiable(entries),
    );
  }

  /// Saldo akhir setiap akun pada [accounts]; akun tanpa mutasi bernilai 0.
  static Map<String, int> balances(
    Iterable<ChartAccount> accounts,
    Iterable<FinanceTransaction> transactions,
  ) {
    final byCode = {for (final a in accounts) a.code: a};
    final result = {for (final code in byCode.keys) code: 0};
    for (final tx in _approvedSorted(transactions)) {
      final posting = postingOf(tx);
      final debitAccount = byCode[posting.debit];
      if (debitAccount != null) {
        result[debitAccount.code] =
            result[debitAccount.code]! +
            signedAmount(debitAccount, debit: tx.amount);
      }
      final creditAccount = byCode[posting.credit];
      if (creditAccount != null) {
        result[creditAccount.code] =
            result[creditAccount.code]! +
            signedAmount(creditAccount, credit: tx.amount);
      }
    }
    return result;
  }
}

/// Akun Kas/Bank ([isCashBankAccount]) termasuk yang nonaktif, agar saldo
/// historisnya tetap terhitung dalam total. Diurutkan per kode.
List<ChartAccount> cashBankAccounts(Iterable<ChartAccount> accounts) =>
    accounts.where(isCashBankAccount).toList()
      ..sort((a, b) => a.code.compareTo(b.code));
