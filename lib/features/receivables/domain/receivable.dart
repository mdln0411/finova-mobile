import '../../transactions/domain/finance_transaction.dart';
import 'bill.dart';

enum ReceivableStatus {
  pending('Menunggu persetujuan'),
  approved('Disetujui'),
  rejected('Ditolak');

  const ReceivableStatus(this.label);
  final String label;
}

abstract final class ReceivableLimits {
  static const maxAmount = 999999999999999;
  static const maxCustomerName = 100;
  static const maxNumber = 50;
  static const maxDescription = 200;
}

class Receivable {
  const Receivable({
    required this.id,
    required this.customerName,
    required this.number,
    required this.amount,
    required this.revenueAccountId,
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
  final String customerName;
  final String number;
  final int amount;
  final String revenueAccountId;
  final DateTime dueDate;
  final String description;
  final ReceivableStatus status;
  final String createdBy;
  final DateTime createdAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectReason;

  bool get isPending => status == ReceivableStatus.pending;
  bool canModify(String? uid) => isPending && uid != null && createdBy == uid;

  int remainingAmount(Iterable<Bill> bills) {
    final remaining =
        amount -
        bills
            .where((bill) => bill.isApproved)
            .fold<int>(0, (total, bill) => total + bill.amount);
    return remaining > 0 ? remaining : 0;
  }

  String paymentStatus(int remaining, {DateTime? now}) {
    if (status == ReceivableStatus.pending) return status.label;
    if (status == ReceivableStatus.rejected) return status.label;
    if (remaining <= 0) return 'Lunas';
    if (dateOnly(dueDate).isBefore(dateOnly(now ?? DateTime.now()))) {
      return 'Terlambat';
    }
    return 'Belum lunas';
  }
}

class ReceivableDraft {
  const ReceivableDraft({
    required this.customerName,
    required this.number,
    required this.amount,
    required this.revenueAccountId,
    required this.dueDate,
    required this.description,
  });

  final String customerName;
  final String number;
  final int amount;
  final String revenueAccountId;
  final DateTime dueDate;
  final String description;

  String? validate({DateTime? bookkeepingStartDate}) {
    final customer = customerName.trim();
    if (customer.isEmpty ||
        customer.length > ReceivableLimits.maxCustomerName) {
      return 'Nama customer wajib diisi (maksimal ${ReceivableLimits.maxCustomerName} karakter).';
    }
    final invoiceNumber = number.trim();
    if (invoiceNumber.isEmpty ||
        invoiceNumber.length > ReceivableLimits.maxNumber) {
      return 'Nomor piutang wajib diisi (maksimal ${ReceivableLimits.maxNumber} karakter).';
    }
    if (amount <= 0 || amount > ReceivableLimits.maxAmount) {
      return amount <= 0
          ? 'Jumlah harus lebih dari Rp 0.'
          : 'Jumlah terlalu besar.';
    }
    if (!RegExp(r'^4[0-9]{3}$').hasMatch(revenueAccountId)) {
      return 'Pilih akun Pendapatan.';
    }
    final due = dateOnly(dueDate);
    if (due.year < 1900 || due.year > 2100) {
      return 'Tanggal jatuh tempo tidak valid.';
    }
    if (bookkeepingStartDate != null &&
        due.isBefore(dateOnly(bookkeepingStartDate))) {
      return 'Jatuh tempo tidak boleh sebelum awal pembukuan.';
    }
    if (description.trim().length > ReceivableLimits.maxDescription) {
      return 'Keterangan maksimal ${ReceivableLimits.maxDescription} karakter.';
    }
    return null;
  }
}

class ReceivableFailure implements Exception {
  const ReceivableFailure(this.message);
  final String message;
}
