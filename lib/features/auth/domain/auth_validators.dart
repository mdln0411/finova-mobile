abstract final class AuthValidators {
  static String normalizePhone(String value) =>
      value.trim().replaceAll(RegExp(r'[\s()\-]'), '');

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return RegExp(r'^\+?[0-9]{7,15}$').hasMatch(normalizePhone(value))
        ? null
        : 'Masukkan nomor telepon 7–15 digit, dengan awalan + jika diperlukan.';
  }

  static String? name(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Masukkan nama lengkap Anda.';
    if (name.length < 2) return 'Nama minimal 2 karakter.';
    if (name.length > 100) return 'Nama maksimal 100 karakter.';
    return null;
  }

  static String? email(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Masukkan alamat email Anda.';
    if (email.length > 320 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Masukkan alamat email yang valid.';
    }
    return null;
  }

  static String? loginPassword(String? value) =>
      value == null || value.isEmpty ? 'Masukkan password Anda.' : null;

  static String? registerPassword(String? value) {
    if (value == null || value.isEmpty) return 'Buat password untuk akun Anda.';
    if (value.length < 8) return 'Gunakan minimal 8 karakter.';
    if (value.length > 128) return 'Password maksimal 128 karakter.';
    if (value.trim().isEmpty) return 'Password tidak boleh hanya berupa spasi.';
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Ulangi password Anda.';
    return value != password ? 'Konfirmasi password belum sesuai.' : null;
  }
}
