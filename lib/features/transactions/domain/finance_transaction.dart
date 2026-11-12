import '../../chart_of_accounts/domain/chart_account.dart';
import '../../chart_of_accounts/domain/default_chart_of_accounts.dart';

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

/// Klasifikasi Kas/Bank: akun posting aset dengan kode 11xx atau 12xx.
/// Tidak memeriksa status aktif; form transaksi menambahkan `isActive`.
bool isCashBankAccount(ChartAccount account) =>
    account.type == AccountType.asset &&
    account.isPosting &&
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
    this.receivableId,
    this.payableId,
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

  /// Tagihan yang dibayar transaksi ini (opsional, maksimal salah satu).
  final String? receivableId;
  final String? payableId;

  bool get isPending => status == TransactionStatus.pending;
  bool canModify(String? uid) => isPending && uid != null && createdBy == uid;

  TransactionDraft toDraft() => TransactionDraft(
    type: type,
    amount: amount,
    date: date,
    description: description,
    cashAccountId: cashAccountId,
    categoryAccountId: categoryAccountId,
    receivableId: receivableId,
    payableId: payableId,
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
    this.receivableId,
    this.payableId,
  });
  final TransactionType type;
  final int amount;
  final DateTime date;
  final String description;
  final String cashAccountId;
  final String categoryAccountId;
  final String? receivableId;
  final String? payableId;

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
    if (cash == null || !isCashBankAccount(cash) || !cash.isActive) {
      return 'Pilih akun Kas/Bank.';
    }
    final category = accounts
        .where((a) => a.code == categoryAccountId)
        .firstOrNull;
    final billError = _validateBillLink(category);
    if (billError != null) return billError;
    if (receivableId != null || payableId != null) return null;
    if (category == null || !isCategoryAccount(category, type)) {
      return type == TransactionType.income
          ? 'Pilih kategori akun Pendapatan.'
          : 'Pilih kategori akun Beban.';
    }
    return null;
  }

  /// Pembayaran tagihan wajib memakai akun kontrol Piutang/Utang sebagai
  /// kategori, sehingga pendapatan/beban tidak tercatat dua kali.
  String? _validateBillLink(ChartAccount? category) {
    final receivable = receivableId?.trim();
    final payable = payableId?.trim();
    if (receivable != null && payable != null) {
      return 'Transaksi hanya boleh membayar satu tagihan.';
    }
    if (receivable != null) {
      if (receivable.isEmpty) return 'Tagihan piutang tidak valid.';
      if (type != TransactionType.income) {
        return 'Pembayaran piutang harus berupa Pemasukan.';
      }
      if (categoryAccountId != receivableAccountCode ||
          !_isActiveControl(category, AccountType.asset)) {
        return 'Pembayaran piutang wajib memakai akun Piutang usaha.';
      }
    }
    if (payable != null) {
      if (payable.isEmpty) return 'Tagihan utang tidak valid.';
      if (type != TransactionType.expense) {
        return 'Pembayaran utang harus berupa Pengeluaran.';
      }
      if (categoryAccountId != payableAccountCode ||
          !_isActiveControl(category, AccountType.liability)) {
        return 'Pembayaran utang wajib memakai akun Utang usaha.';
      }
    }
    return null;
  }

  static bool _isActiveControl(ChartAccount? account, AccountType type) =>
      account != null &&
      account.type == type &&
      account.isPosting &&
      account.isActive;
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
