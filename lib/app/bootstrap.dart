import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/data/firebase_auth_repository.dart';
import '../features/auth/presentation/widgets/auth_layout.dart';
import '../firebase_options.dart';
import 'app.dart';
import 'theme/app_theme.dart';

Future<AuthController> initializeAuthentication() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  return AuthController(FirebaseAuthRepository());
}

Future<AuthController?> tryInitializeAuthentication() async {
  try {
    return await initializeAuthentication();
  } catch (_) {
    return null;
  }
}

/// Root memiliki controller; FinovaApp hanya memiliki router.
/// Firebase ditunggu sebelum runApp, dengan pemulihan jika inisialisasi gagal.
class FinovaBootstrap extends StatefulWidget {
  const FinovaBootstrap({
    super.key,
    this.initialController,
    this.initialize = initializeAuthentication,
  });
  final AuthController? initialController;
  final Future<AuthController> Function() initialize;
  @override
  State<FinovaBootstrap> createState() => _FinovaBootstrapState();
}

class _FinovaBootstrapState extends State<FinovaBootstrap> {
  late AuthController? _controller = widget.initialController;
  bool _loading = false;

  Future<void> _retry() async {
    if (_loading) return;
    setState(() => _loading = true);
    AuthController? controller;
    try {
      controller = await widget.initialize();
    } catch (_) {
      /* Pesan aman ditampilkan di bawah, tanpa konfigurasi mentah. */
    }
    if (!mounted) {
      controller?.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _controller != null
      ? FinovaApp(authController: _controller!)
      : MaterialApp(
          title: 'Finova',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: AuthLayout(
            title: 'Belum dapat terhubung.',
            subtitle:
                'Finova belum dapat menyiapkan layanan akun. '
                'Periksa koneksi internet dan coba kembali.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthMessage(
                  message:
                      'Jika kendala berlanjut, hubungi pengelola aplikasi '
                      'untuk memeriksa konfigurasi Firebase pada perangkat ini.',
                ),
                FilledButton(
                  onPressed: _loading ? null : _retry,
                  child: Text(
                    _loading ? 'Menghubungkan…' : 'Coba hubungkan kembali',
                  ),
                ),
              ],
            ),
          ),
        );
}
