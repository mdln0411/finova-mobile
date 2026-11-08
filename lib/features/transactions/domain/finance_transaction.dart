import '../../chart_of_accounts/domain/chart_account.dart';

enum TransactionType {
  income('Pemasukan', AccountType.revenue),
  expense('Pengeluaran', AccountType.expense);

  const TransactionType(this.label, this.categoryType);
  final String label;

  /// Tipe akun COA yang sah sebagai kategori transaksi ini.
  final AccountType categoryType;
}

enum TransactionStatus {
  pending('Menunggu'),
  approved('Disetujui'),
  rejected('Ditolak');

  const TransactionStatus(this.label);
  final String label;
}

/// Batas sama dengan Firestore Rules (`validTransactionBody`).
abstract final class TransactionLimits {
  static const maxAmount = 999999999999999;
  static const maxDescription = 200;
  static const minRejectReason = 3;
  static const maxRejectReason = 500;
}

/// Akun Kas/Bank: akun posting aset aktif dengan kode 11xx atau 12xx.
bool isCashAccount(ChartAccount account) =>
    account.type == AccountType.asset &&
    account.isPosting &&
    account.isActive &&
    RegExp(r'^1[12][0-9]{2}$').hasMatch(account.code);

bool isCategoryAccount(ChartAccount account, TransactionType type) =>
    account.type == type.categoryType && account.isPosting && account.isActive;

DateTime dateOnly(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

/// Transaksi pemasukan/pengeluaran. Nominal integer Rupiah (tanpa desimal).
/// Hanya transaksi `approved` yang nantinya boleh memengaruhi saldo/ledger.
class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    required this.description,
    required this.cashAccountId,
    required this.categoryAccountId,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    this.approvedBy,
    this.approvedAt,
    this.rejectReason,
  });
  final String id;
  final TransactionType type;
  final int amount;
  final DateTime date;
  final String description;
  final String cashAccountId;
  final String categoryAccountId;
  final TransactionStatus status;
  final String createdBy;
  final DateTime createdAt;

  /// Pengambil keputusan (setujui atau tolak).
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectReason;

  bool get isPending => status == TransactionStatus.pending;
  bool canModify(String? uid) => isPending && uid != null && createdBy == uid;

  TransactionDraft toDraft() => TransactionDraft(
    type: type,
    amount: amount,
    date: date,
    description: description,
    cashAccountId: cashAccountId,
    categoryAccountId: categoryAccountId,
  );
}

class TransactionDraft {
  const TransactionDraft({
    required this.type,
    required this.amount,
    required this.date,
    required this.description,
    required this.cashAccountId,
    required this.categoryAccountId,
  });
  final TransactionType type;
  final int amount;
  final DateTime date;
  final String description;
  final String cashAccountId;
  final String categoryAccountId;

  /// Validasi client untuk UX. Rules tetap menjadi pengaman utama.
  String? validate({
    required List<ChartAccount> accounts,
    DateTime? bookkeepingStartDate,
    DateTime? now,
  }) {
    if (amount <= 0) return 'Nominal harus lebih dari Rp 0.';
    if (amount > TransactionLimits.maxAmount) return 'Nominal terlalu besar.';
    final day = dateOnly(date);
    if (bookkeepingStartDate != null &&
        day.isBefore(dateOnly(bookkeepingStartDate))) {
      return 'Tanggal tidak boleh sebelum awal pembukuan.';
    }
    if (day.isAfter(dateOnly(now ?? DateTime.now()))) {
      return 'Tanggal tidak boleh di masa depan.';
    }
    final text = description.trim();
    if (text.isEmpty) return 'Keterangan wajib diisi.';
    if (text.length > TransactionLimits.maxDescription) {
      return 'Keterangan maksimal ${TransactionLimits.maxDescription} karakter.';
    }
    final cash = accounts.where((a) => a.code == cashAccountId).firstOrNull;
    if (cash == null || !isCashAccount(cash)) return 'Pilih akun Kas/Bank.';
    final category = accounts
        .where((a) => a.code == categoryAccountId)
        .firstOrNull;
    if (category == null || !isCategoryAccount(category, type)) {
      return type == TransactionType.income
          ? 'Pilih kategori akun Pendapatan.'
          : 'Pilih kategori akun Beban.';
    }
    return null;
  }
}

/// Terbaru lebih dulu: tanggal transaksi, lalu waktu dibuat.
void sortTransactions(List<FinanceTransaction> items) => items.sort((a, b) {
  final byDate = b.date.compareTo(a.date);
  return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
});

String? validateRejectReason(String? value) {
  final text = value?.trim() ?? '';
  if (text.length < TransactionLimits.minRejectReason) {
    return 'Alasan penolakan minimal ${TransactionLimits.minRejectReason} karakter.';
  }
  if (text.length > TransactionLimits.maxRejectReason) {
    return 'Alasan penolakan maksimal ${TransactionLimits.maxRejectReason} karakter.';
  }
  return null;
}

class TransactionFailure implements Exception {
  const TransactionFailure(this.message);
  final String message;
}
