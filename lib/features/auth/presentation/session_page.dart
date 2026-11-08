import 'package:flutter/material.dart';

import '../application/auth_controller.dart';
import 'widgets/auth_layout.dart';

class SessionPage extends StatelessWidget {
  const SessionPage({super.key, required this.controller});
  final AuthController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final failed =
          controller.phase == AuthPhase.profileError ||
          controller.phase == AuthPhase.sessionError;
      return AuthLayout(
        title: failed ? 'Selesaikan koneksi akun.' : 'Menyiapkan ruang kerja.',
        subtitle: failed
            ? 'Akun Anda tetap aman. Coba kembali tanpa membuat akun baru.'
            : 'Kami sedang memeriksa sesi dan menyiapkan profil Anda.',
        child: failed
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthMessage(
                    message:
                        controller.sessionMessage ?? 'Sesi belum tersedia.',
                  ),
                  FilledButton(
                    onPressed: controller.busy ? null : controller.retrySession,
                    child: const Text('Coba lagi'),
                  ),
                  TextButton(
                    onPressed: controller.busy ? null : controller.signOut,
                    child: const Text('Keluar ke Login'),
                  ),
                ],
              )
            : const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Memeriksa sesi akun',
                ),
              ),
      );
    },
  );
}
