class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
}

class ProfileSyncFailure extends AuthFailure {
  ProfileSyncFailure({required this.code, required this.operation})
    : super(
        code == 'permission-denied'
            ? 'Akses ${operation == 'read'
                      ? 'baca'
                      : operation == 'complete'
                      ? 'penyimpanan'
                      : 'pembuatan'} profil ditolak. '
                  'Akun Anda sudah masuk. Pengelola perlu memeriksa izin profil sebelum Anda mencoba lagi.'
            : 'Profil belum dapat diakses. Periksa koneksi Anda dan coba lagi.',
      );

  final String code;
  final String operation;
}
