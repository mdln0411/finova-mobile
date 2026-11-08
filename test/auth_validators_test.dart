import 'package:finova/features/auth/data/auth_error_message.dart';
import 'package:finova/features/auth/domain/auth_validators.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() {
  test('Email dan nama divalidasi tanpa menolak nama satu kata', () {
    expect(AuthValidators.email(''), isNotNull);
    expect(AuthValidators.email('andi@'), isNotNull);
    expect(AuthValidators.email('a b@example.com'), isNotNull);
    expect(AuthValidators.email(' andi+finance@example.co.id '), isNull);
    expect(AuthValidators.name('  '), isNotNull);
    expect(AuthValidators.name('A'), isNotNull);
    expect(AuthValidators.name('Andi'), isNull);
    expect(AuthValidators.name('a' * 101), isNotNull);
  });
  test('Password login lama tidak terkena kebijakan password registrasi', () {
    expect(AuthValidators.loginPassword(''), isNotNull);
    expect(AuthValidators.loginPassword('123456'), isNull);
    expect(AuthValidators.registerPassword('1234567'), isNotNull);
    expect(AuthValidators.registerPassword('        '), isNotNull);
    expect(AuthValidators.registerPassword('password123'), isNull);
    expect(
      AuthValidators.confirmPassword('password12', 'password123'),
      isNotNull,
    );
    expect(
      AuthValidators.confirmPassword('password123', 'password123'),
      isNull,
    );
  });
  test('Pesan login tidak mengungkap detail SDK atau keberadaan akun', () {
    expect(
      authErrorMessage(FirebaseAuthException(code: 'user-not-found')),
      authErrorMessage(FirebaseAuthException(code: 'wrong-password')),
    );
    expect(
      authErrorMessage(
        FirebaseAuthException(code: 'unknown', message: 'SECRET'),
      ),
      isNot(contains('SECRET')),
    );
    expect(
      authErrorMessage(
        const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
      ),
      'Login Google dibatalkan.',
    );
  });
}
