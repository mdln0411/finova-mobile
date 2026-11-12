import '../../chart_of_accounts/domain/chart_account.dart';
import '../../chart_of_accounts/domain/default_chart_of_accounts.dart';
import '../../payables/domain/payable.dart';
import '../../receivables/domain/receivable.dart';
import '../../transactions/domain/bill.dart';
import '../../transactions/domain/finance_transaction.dart';

/// Asal jurnal. ID sumber hanya unik di dalam jenisnya.
enum JournalSource { transaction, receivable, payable }

/// Satu jurnal double-entry dari sumber yang sudah disetujui.
class JournalLine {
  const JournalLine({
    required this.source,
    required this.sourceId,
    required this.date,
    required this.createdAt,
    required this.description,
    required this.debitAccountId,
    required this.creditAccountId,
    required this.amount,
  });
  final JournalSource source;
  final String sourceId;
  final DateTime date;
  final DateTime createdAt;
  final String description;
  final String debitAccountId;
  final String creditAccountId;
  final int amount;
}

/// Satu baris buku besar. Nominal integer Rupiah.
class LedgerEntry {
  const LedgerEntry({
    required this.source,
    required this.sourceId,
    required this.date,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
  });
  final JournalSource source;
  final String sourceId;
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

  /// Saldo dari jurnal sebelum awal rentang (0 tanpa filter awal).
  final int openingBalance;
  final List<LedgerEntry> entries;

  int get totalDebit => entries.fold(0, (sum, e) => sum + e.debit);
  int get totalCredit => entries.fold(0, (sum, e) => sum + e.credit);
  int get closingBalance =>
      entries.isEmpty ? openingBalance : entries.last.balance;
}

/// Menghitung ledger dari sumber yang disetujui tanpa menyimpannya (pure Dart).
/// Sumber berstatus pending/rejected diabaikan.
///
/// Double-entry:
/// - transaksi income : debit Kas/Bank, kredit kategori (Pendapatan/Piutang).
/// - transaksi expense: debit kategori (Beban/Utang), kredit Kas/Bank.
/// - piutang          : debit akun Piutang, kredit akun Pendapatan.
/// - utang            : debit akun Beban, kredit akun Utang.
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

  static JournalLine _fromTransaction(FinanceTransaction tx) {
    final posting = postingOf(tx);
    return JournalLine(
      source: JournalSource.transaction,
      sourceId: tx.id,
      date: dateOnly(tx.date),
      createdAt: tx.createdAt,
      description: tx.description,
      debitAccountId: posting.debit,
      creditAccountId: posting.credit,
      amount: tx.amount,
    );
  }

  static JournalLine _fromBill(
    Bill bill,
    JournalSource source, {
    required String debit,
    required String credit,
  }) => JournalLine(
    source: source,
    sourceId: bill.id,
    date: dateOnly(bill.issueDate),
    createdAt: bill.createdAt,
    description: '${bill.number} · ${bill.partyName} · ${bill.description}',
    debitAccountId: debit,
    creditAccountId: credit,
    amount: bill.amount,
  );

  /// Seluruh jurnal approved, kronologis dan deterministik.
  static List<JournalLine> journal(
    Iterable<FinanceTransaction> transactions, {
    Iterable<Receivable> receivables = const [],
    Iterable<Payable> payables = const [],
  }) {
    final lines = <JournalLine>[
      for (final tx in transactions)
        if (tx.status == TransactionStatus.approved) _fromTransaction(tx),
      for (final r in receivables)
        if (r.isApproved)
          _fromBill(
            r,
            JournalSource.receivable,
            debit: receivableAccountCode,
            credit: r.revenueAccountId,
          ),
      for (final p in payables)
        if (p.isApproved)
          _fromBill(
            p,
            JournalSource.payable,
            debit: p.expenseAccountId,
            credit: payableAccountCode,
          ),
    ];
    lines.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
      final byCreated = a.createdAt.compareTo(b.createdAt);
      if (byCreated != 0) return byCreated;
      final bySource = a.source.index.compareTo(b.source.index);
      return bySource != 0 ? bySource : a.sourceId.compareTo(b.sourceId);
    });
    return lines;
  }

  /// Ledger satu akun. [from] dan [to] inklusif (per tanggal).
  static AccountLedger forAccount(
    ChartAccount account,
    Iterable<FinanceTransaction> transactions, {
    Iterable<Receivable> receivables = const [],
    Iterable<Payable> payables = const [],
    DateTime? from,
    DateTime? to,
  }) {
    final start = from == null ? null : dateOnly(from);
    final end = to == null ? null : dateOnly(to);
    var opening = 0;
    var balance = 0;
    final entries = <LedgerEntry>[];
    final lines = journal(
      transactions,
      receivables: receivables,
      payables: payables,
    );
    for (final line in lines) {
      final debit = line.debitAccountId == account.code ? line.amount : 0;
      final credit = line.creditAccountId == account.code ? line.amount : 0;
      if (debit == 0 && credit == 0) continue;
      if (end != null && line.date.isAfter(end)) break;
      final delta = signedAmount(account, debit: debit, credit: credit);
      if (start != null && line.date.isBefore(start)) {
        opening += delta;
        balance = opening;
        continue;
      }
      balance += delta;
      entries.add(
        LedgerEntry(
          source: line.source,
          sourceId: line.sourceId,
          date: line.date,
          description: line.description,
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
    Iterable<FinanceTransaction> transactions, {
    Iterable<Receivable> receivables = const [],
    Iterable<Payable> payables = const [],
  }) {
    final byCode = {for (final a in accounts) a.code: a};
    final result = {for (final code in byCode.keys) code: 0};
    final lines = journal(
      transactions,
      receivables: receivables,
      payables: payables,
    );
    for (final line in lines) {
      final debitAccount = byCode[line.debitAccountId];
      if (debitAccount != null) {
        result[debitAccount.code] =
            result[debitAccount.code]! +
            signedAmount(debitAccount, debit: line.amount);
      }
      final creditAccount = byCode[line.creditAccountId];
      if (creditAccount != null) {
        result[creditAccount.code] =
            result[creditAccount.code]! +
            signedAmount(creditAccount, credit: line.amount);
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
