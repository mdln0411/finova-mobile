import 'chart_account.dart';

abstract interface class ChartOfAccountsRepository {
  Stream<List<ChartAccount>> watchAccounts(String companyId);

  /// Membuat akun default yang belum ada; tidak mengubah/menghapus akun lama.
  /// Mengembalikan jumlah akun yang dibuat setelah commit berhasil.
  Future<int> initializeDefaults(String companyId);
}
