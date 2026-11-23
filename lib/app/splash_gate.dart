import 'package:flutter/material.dart';

import '../core/widgets/finova_splash.dart';
import '../features/auth/application/auth_controller.dart';

/// Dipasang di atas router. Menampilkan splash animasi setiap aplikasi dibuka
/// sampai animasinya selesai DAN auth tidak lagi loading, lalu splash
/// fade out di atas [child] (MaterialApp.router). Tanpa delay tambahan.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.auth, required this.child});
  final AuthController auth;
  final Widget child;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _revealing = false;
  bool _done = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.auth,
    builder: (context, _) {
      // Di atas MaterialApp belum ada MediaQuery/Directionality.
      // Struktur Stack dijaga tetap agar router tidak dibangun ulang.
      return MediaQuery.fromView(
        view: View.of(context),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_revealing || _done)
                KeyedSubtree(key: const ValueKey('app'), child: widget.child),
              if (!_done)
                FinovaSplash(
                  key: const ValueKey('splash'),
                  ready: widget.auth.phase != AuthPhase.loading,
                  onFadeOut: () => setState(() => _revealing = true),
                  onCompleted: () => setState(() => _done = true),
                ),
            ],
          ),
        ),
      );
    },
  );
}
