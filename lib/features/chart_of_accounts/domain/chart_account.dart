enum BalanceSide {
  debit('Debit'),
  credit('Kredit');

  const BalanceSide(this.label);
  final String label;
}

enum AccountType {
  asset('Aset', '1', BalanceSide.debit),
  liability('Liabilitas', '2', BalanceSide.credit),
  equity('Ekuitas', '3', BalanceSide.credit),
  revenue('Pendapatan', '4', BalanceSide.credit),
  expense('Beban', '5', BalanceSide.debit);

  const AccountType(this.label, this.codePrefix, this.normalBalance);
  final String label;
  final String codePrefix;
  final BalanceSide normalBalance;
  String get groupCode => '${codePrefix}000';
}

/// Akun buku besar, bukan transaksi, saldo, rekening bank, atau kategori arus kas.
/// Versi awal memakai dua tingkat: kelompok x000 dan akun posting di bawahnya.
class ChartAccount {
  const ChartAccount({
    required this.code,
    required this.name,
    required this.type,
    required this.normalBalance,
    required this.isPosting,
    this.parentCode,
    this.isActive = true,
  });
  final String code;
  final String name;
  final AccountType type;
  final BalanceSide normalBalance;
  final bool isPosting;
  final String? parentCode;
  final bool isActive;

  String? validate() {
    if (!RegExp(r'^[1-5][0-9]{3}$').hasMatch(code) ||
        !code.startsWith(type.codePrefix)) {
      return 'Kode akun harus 4 digit dan sesuai kelompok akun.';
    }
    if (name.trim().length < 2 ||
        name.length > 100 ||
        name != name.trim() ||
        RegExp(r'[\r\n\t]').hasMatch(name)) {
      return 'Nama akun harus 2–100 karakter tanpa spasi luar atau baris baru.';
    }
    if (normalBalance != type.normalBalance) {
      return 'Saldo normal tidak sesuai tipe akun.';
    }
    if (code == type.groupCode) {
      if (isPosting || parentCode != null) {
        return 'Kelompok akun tidak boleh dipakai untuk posting.';
      }
    } else if (!isPosting || parentCode != type.groupCode) {
      return 'Akun posting harus berada di kelompok dengan tipe yang sama.';
    }
    return null;
  }

  static void validateChart(List<ChartAccount> accounts) {
    final byCode = <String, ChartAccount>{};
    for (final account in accounts) {
      final error = account.validate();
      if (error != null || byCode.containsKey(account.code)) {
        throw ChartOfAccountsFailure(error ?? 'Terdapat kode akun duplikat.');
      }
      byCode[account.code] = account;
    }
    for (final account in accounts.where((account) => account.isPosting)) {
      final parent = byCode[account.parentCode];
      if (parent == null || parent.isPosting || parent.type != account.type) {
        throw const ChartOfAccountsFailure(
          'Kelompok induk akun belum tersedia atau tidak sesuai.',
        );
      }
    }
  }
}

class ChartOfAccountsFailure implements Exception {
  const ChartOfAccountsFailure(this.message);
  final String message;
}
