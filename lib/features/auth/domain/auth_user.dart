/// Identitas sesi tanpa token atau hak akses perusahaan.
class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
  });
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
}

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.phoneNumber,
    this.profileCompleted = false,
  });
  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final String? phoneNumber;
  final bool profileCompleted;
}
