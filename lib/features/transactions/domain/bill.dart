import 'dart:math' as math;

import '../../chart_of_accounts/domain/chart_account.dart';
import 'finance_transaction.dart';

/// Batas field tagihan; nominal dan keterangan memakai [TransactionLimits].
abstract final class BillLimits {
  static const maxNumber = 50;
  static const maxPartyName = 100;
}

enum SettlementStatus {
  unpaid('Belum dibayar'),
  partial('Dibayar sebagian'),
  paid('Lunas');

  const SettlementStatus(this.label);
  final String label;
}

/// Ringkasan pelunasan tagihan dari pembayaran yang sudah disetujui.
class BillSettlement {
  const BillSettlement({required this.amount, required this.paid});
  final int amount;
  final int paid;

  int get remaining => math.max(0, amount - paid);

  /// Kelebihan bayar (mis. dua pembayaran disetujui bersamaan). Normalnya 0.
  int get overpaid => math.max(0, paid - amount);

  SettlementStatus get status => paid >= amount
      ? SettlementStatus.paid
      : paid > 0
      ? SettlementStatus.partial
      : SettlementStatus.unpaid;

  bool get isPaid => status == SettlementStatus.paid;
}

/// Dasar Piutang (Receivable) dan Utang (Payable). Nominal integer Rupiah.
/// Status persetujuan sama dengan transaksi: pending → approved/rejected.
abstract class Bill {
  const Bill({
    required this.id,
    required this.number,
    required this.amount,
    required this.issueDate,
    required this.dueDate,
    required this.description,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    this.approvedBy,
    this.approvedAt,
    this.rejectReason,
  });
  final String id;
  final String number;
  final int amount;
  final DateTime issueDate;
  final DateTime dueDate;
  final String description;
  final TransactionStatus status;
  final String createdBy;
  final DateTime createdAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectReason;

  /// Nama pelanggan (piutang) atau pemasok (utang).
  String get partyName;

  /// Akun pendapatan (piutang) atau beban (utang) lawan jurnal tagihan.
  String get counterAccountId;

  /// Jenis transaksi pembayaran: income untuk piutang, expense untuk utang.
  TransactionType get paymentType;

  /// ID tagihan yang dibayar oleh [tx] untuk jenis tagihan ini.
  String? linkedBillId(FinanceTransaction tx);

  bool get isApproved => status == TransactionStatus.approved;

  bool isOverdue(DateTime today, BillSettlement settlement) =>
      !settlement.isPaid && dateOnly(today).isAfter(dateOnly(dueDate));

  /// Pembayaran sah: transaksi `approved`, jenis sesuai, dan tertaut ke ID ini.
  bool isPaymentOf(FinanceTransaction tx) =>
      tx.status == TransactionStatus.approved &&
      tx.type == paymentType &&
      linkedBillId(tx) == id;

  BillSettlement settlement(Iterable<FinanceTransaction> transactions) =>
      BillSettlement(
        amount: amount,
        paid: transactions
            .where(isPaymentOf)
            .fold(0, (sum, tx) => sum + tx.amount),
      );

  /// Validasi client untuk UX. Rules tetap menjadi pengaman utama.
  String? validate({
    required List<ChartAccount> accounts,
    DateTime? bookkeepingStartDate,
    DateTime? now,
  }) {
    final name = partyName.trim();
    if (name.isEmpty) {
      return paymentType == TransactionType.income
          ? 'Nama pelanggan wajib diisi.'
          : 'Nama pemasok wajib diisi.';
    }
    if (name.length > BillLimits.maxPartyName) {
      return 'Nama maksimal ${BillLimits.maxPartyName} karakter.';
    }
    final code = number.trim();
    if (code.isEmpty) return 'Nomor tagihan wajib diisi.';
    if (code.length > BillLimits.maxNumber) {
      return 'Nomor tagihan maksimal ${BillLimits.maxNumber} karakter.';
    }
    if (amount <= 0) return 'Nominal harus lebih dari Rp 0.';
    if (amount > TransactionLimits.maxAmount) return 'Nominal terlalu besar.';
    final issue = dateOnly(issueDate);
    if (bookkeepingStartDate != null &&
        issue.isBefore(dateOnly(bookkeepingStartDate))) {
      return 'Tanggal tagihan tidak boleh sebelum awal pembukuan.';
    }
    if (issue.isAfter(dateOnly(now ?? DateTime.now()))) {
      return 'Tanggal tagihan tidak boleh di masa depan.';
    }
    if (dateOnly(dueDate).isBefore(issue)) {
      return 'Jatuh tempo tidak boleh sebelum tanggal tagihan.';
    }
    final text = description.trim();
    if (text.isEmpty) return 'Keterangan wajib diisi.';
    if (text.length > TransactionLimits.maxDescription) {
      return 'Keterangan maksimal ${TransactionLimits.maxDescription} karakter.';
    }
    final account = accounts
        .where((a) => a.code == counterAccountId)
        .firstOrNull;
    if (account == null || !isCategoryAccount(account, paymentType)) {
      return paymentType == TransactionType.income
          ? 'Pilih akun Pendapatan.'
          : 'Pilih akun Beban.';
    }
    return null;
  }
}
