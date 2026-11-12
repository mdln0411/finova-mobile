import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/auth_failure.dart';
import '../domain/auth_user.dart';
import '../domain/auth_validators.dart';

class UserProfileService {
  UserProfileService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _firestore;

  Future<UserProfile> ensureProfile(AuthUser user) async {
    var operation = 'read';
    try {
      return await _firestore
          .runTransaction((transaction) async {
            final reference = _firestore.collection('users').doc(user.uid);
            final snapshot = await transaction.get(reference);
            final existing = snapshot.data();
            if (existing != null && existing['uid'] != user.uid) {
              throw const AuthFailure(
                'Identitas profil tidak sesuai. Hubungi pengelola aplikasi.',
              );
            }
            if (existing != null) {
              final name = existing['displayName'];
              final photo = existing['photoUrl'];
              if (name is! String ||
                  name.trim().isEmpty ||
                  name.length > 100 ||
                  (photo != null && photo is! String)) {
                throw const AuthFailure(
                  'Format profil belum sesuai. Hubungi pengelola aplikasi.',
                );
              }
              // Login bukan perubahan profil. Jangan menulis ulang profil lama,
              // timestamp, atau field lain yang dikelola server.
              return UserProfile(
                uid: user.uid,
                displayName: name,
                email: user.email,
                photoUrl: photo as String?,
                phoneNumber: existing['phoneNumber'] is String
                    ? existing['phoneNumber'] as String
                    : null,
                profileCompleted:
                    existing['profileCompleted'] == true &&
                    AuthValidators.name(name) == null,
              );
            }
            final fallback = user.displayName?.trim();
            final displayName = (fallback != null && fallback.isNotEmpty
                ? fallback
                : 'Pengguna Finova');
            final profile = UserProfile(
              uid: user.uid,
              displayName: displayName.length > 100
                  ? displayName.substring(0, 100)
                  : displayName,
              email: user.email,
              photoUrl: user.photoUrl,
            );
            final values = <String, dynamic>{
              'displayName': profile.displayName,
              'email': profile.email,
              'photoUrl': profile.photoUrl,
              'updatedAt': FieldValue.serverTimestamp(),
              'profileCompleted': false,
            };
            operation = 'create';
            transaction.set(reference, {
              ...values,
              'uid': user.uid,
              'createdAt': FieldValue.serverTimestamp(),
            });
            return profile;
          })
          .timeout(const Duration(seconds: 20));
    } on FirebaseException catch (error) {
      // Tidak mencatat UID, email, token, atau isi dokumen pengguna.
      developer.log(
        'profile_sync operation=$operation code=${error.code}',
        name: 'finova.auth',
      );
      throw ProfileSyncFailure(code: error.code, operation: operation);
    }
  }

  Future<UserProfile> completeProfile(
    AuthUser user,
    String name,
    String? phoneNumber,
  ) async {
    final nameError = AuthValidators.name(name);
    final phoneError = AuthValidators.phone(phoneNumber);
    if (nameError != null || phoneError != null) {
      throw AuthFailure(nameError ?? phoneError!);
    }
    final phone = phoneNumber == null || phoneNumber.trim().isEmpty
        ? null
        : AuthValidators.normalizePhone(phoneNumber);
    try {
      return await _firestore
          .runTransaction((transaction) async {
            final reference = _firestore.collection('users').doc(user.uid);
            final snapshot = await transaction.get(reference);
            final existing = snapshot.data();
            if (existing != null && existing['uid'] != user.uid) {
              throw const AuthFailure(
                'Identitas profil tidak sesuai. Hubungi pengelola aplikasi.',
              );
            }
            final storedPhoto = existing?['photoUrl'];
            final photo =
                user.photoUrl ?? (storedPhoto is String ? storedPhoto : null);
            final safePhoto =
                photo != null && Uri.tryParse(photo)?.scheme == 'https'
                ? photo
                : null;
            final profile = UserProfile(
              uid: user.uid,
              displayName: name.trim(),
              email: user.email,
              photoUrl: safePhoto,
              phoneNumber: phone,
              profileCompleted: true,
            );
            final values = <String, dynamic>{
              'displayName': profile.displayName,
              'email': user.email,
              'photoUrl': safePhoto,
              'phoneNumber': phone,
              'profileCompleted': true,
              'updatedAt': FieldValue.serverTimestamp(),
            };
            if (snapshot.exists) {
              transaction.update(reference, values);
            } else {
              transaction.set(reference, {
                ...values,
                'uid': user.uid,
                'createdAt': FieldValue.serverTimestamp(),
              });
            }
            return profile;
          })
          .timeout(const Duration(seconds: 20));
    } on FirebaseException catch (error) {
      developer.log(
        'profile_sync operation=complete code=${error.code}',
        name: 'finova.auth',
      );
      throw ProfileSyncFailure(code: error.code, operation: 'complete');
    }
  }
}
