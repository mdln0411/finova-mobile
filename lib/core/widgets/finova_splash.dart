import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/theme/app_colors.dart';
import 'finova_logo.dart' show finovaLogoAsset;

// Logo dipecah dua lapis (badan + koin) agar koin bisa memantul sendiri.
// Sumber: assets/images/finova_logo.svg.
const _logoBodySvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#2F62F2"/><stop offset="1" stop-color="#1D44C9"/>
  </linearGradient></defs>
  <rect width="200" height="200" rx="46" fill="url(#bg)"/>
  <rect x="58" y="42" width="90" height="32" rx="16" fill="#FFFFFF"/>
  <rect x="58" y="92" width="64" height="30" rx="15" fill="#FF5C93"/>
  <rect x="58" y="42" width="32" height="116" rx="16" fill="#FFFFFF"/>
</svg>''';

const _logoCoinSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
  <circle cx="136" cy="144" r="18" fill="#FFC93C"/>
  <circle cx="136" cy="144" r="12" fill="none" stroke="#E5A800" stroke-width="2.5"/>
  <path d="M126 139 A11 11 0 0 1 134 132" fill="none" stroke="#FFFFFF"
    stroke-width="2.5" stroke-linecap="round" opacity="0.85"/>
</svg>''';

double _at(double seconds) => seconds / 2.2;

/// Splash animasi (~2,2 dtk, waktu dalam detik):
/// - 0–0,6: logo muncul (scale 0,6→1,0 elastis lembut) sambil fade in.
/// - 0,5–1,1: koin memantul sekali + kilau putih tipis melintas diagonal.
/// - 0,9–1,5: teks "finova" fade in sambil naik dari bawah.
/// - 1,5–1,8: tahan (dan menunggu [ready] bila auth belum siap).
/// - 1,8–2,2: seluruh splash fade out, lalu [onCompleted].
/// Reduce motion (MediaQuery.disableAnimations): hanya fade in/out sederhana.
class FinovaSplash extends StatefulWidget {
  const FinovaSplash({
    super.key,
    this.ready = true,
    this.onFadeOut,
    this.onCompleted,
  });

  /// Auth sudah tidak loading; splash boleh fade out.
  final bool ready;
  final VoidCallback? onFadeOut;
  final VoidCallback? onCompleted;

  static const duration = Duration(milliseconds: 2200);
  static const reducedDuration = Duration(milliseconds: 500);

  /// Sama dengan native splash (Android & web) agar perpindahan mulus.
  static const logoSize = 140.0;

  @override
  State<FinovaSplash> createState() => _FinovaSplashState();
}

class _FinovaSplashState extends State<FinovaSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: FinovaSplash.duration,
  );
  bool _started = false;
  bool _reduceMotion = false;
  bool _fadingOut = false;

  // Titik tahan: splash berhenti di sini bila auth belum siap.
  double get _holdPoint => _reduceMotion ? .5 : _at(1.8);

  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _c,
    curve: Interval(0, _at(.35), curve: Curves.easeOut),
  );
  late final Animation<double> _logoScale = Tween(begin: .6, end: 1.0).animate(
    CurvedAnimation(
      parent: _c,
      curve: Interval(0, _at(.6), curve: const ElasticOutCurve(.6)),
    ),
  );
  late final Animation<double> _coinLift = TweenSequence([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.bounceOut)),
      weight: 60,
    ),
  ]).animate(CurvedAnimation(parent: _c, curve: Interval(_at(.5), _at(1.1))));
  late final Animation<double> _shine = CurvedAnimation(
    parent: _c,
    curve: Interval(_at(.5), _at(1.1), curve: Curves.easeInOut),
  );
  late final Animation<double> _textIn = CurvedAnimation(
    parent: _c,
    curve: Interval(_at(.9), _at(1.5), curve: Curves.easeOutCubic),
  );
  late final Animation<double> _reducedIn = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, .5, curve: Curves.easeOut),
  );
  late final Animation<double> _splashOpacity = Tween(begin: 1.0, end: 0.0)
      .animate(
        CurvedAnimation(
          parent: _c,
          curve: Interval(_holdPoint, 1, curve: Curves.easeIn),
        ),
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_reduceMotion) _c.duration = FinovaSplash.reducedDuration;
    _c.animateTo(_holdPoint).whenComplete(_maybeFadeOut);
  }

  @override
  void didUpdateWidget(FinovaSplash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ready && !oldWidget.ready) _maybeFadeOut();
  }

  void _maybeFadeOut() {
    if (!mounted || _fadingOut || !widget.ready || _c.value < _holdPoint) {
      return;
    }
    _fadingOut = true;
    widget.onFadeOut?.call();
    _c.animateTo(1).whenComplete(() {
      if (mounted) widget.onCompleted?.call();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _text = Text(
    'finova',
    textDirection: TextDirection.ltr,
    style: TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      letterSpacing: -1,
      color: AppColors.text,
      decoration: TextDecoration.none,
    ),
  );

  Widget _layer(String svg) => SvgPicture.string(
    svg,
    width: FinovaSplash.logoSize,
    height: FinovaSplash.logoSize,
  );

  // Layar penuh putih; logo tepat di tengah (posisi native splash),
  // teks di bawahnya tanpa menggeser logo.
  Widget _layout(Widget logo, Widget text) => SizedBox.expand(
    child: ColoredBox(
      color: Colors.white,
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            logo,
            Positioned(top: FinovaSplash.logoSize + 20, child: text),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Memuat Finova',
    child: FadeTransition(
      opacity: _splashOpacity,
      child: _reduceMotion
          ? FadeTransition(
              opacity: _reducedIn,
              child: _layout(
                SvgPicture.asset(
                  finovaLogoAsset,
                  width: FinovaSplash.logoSize,
                  height: FinovaSplash.logoSize,
                ),
                _text,
              ),
            )
          : _layout(_animatedLogo(), _animatedText()),
    ),
  );

  Widget _animatedText() => AnimatedBuilder(
    animation: _textIn,
    child: _text,
    builder: (context, text) => Opacity(
      opacity: _textIn.value,
      child: Transform.translate(
        offset: Offset(0, 14 * (1 - _textIn.value)),
        child: text,
      ),
    ),
  );

  Widget _animatedLogo() => FadeTransition(
    opacity: _logoFade,
    child: ScaleTransition(
      scale: _logoScale,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final logo = SizedBox.square(
            dimension: FinovaSplash.logoSize,
            child: Stack(
              children: [
                _layer(_logoBodySvg),
                Transform.translate(
                  // Pantulan kecil koin (sekitar 9% tinggi logo).
                  offset: Offset(
                    0,
                    -FinovaSplash.logoSize * .09 * _coinLift.value,
                  ),
                  child: _layer(_logoCoinSvg),
                ),
              ],
            ),
          );
          final t = _shine.value;
          if (t == 0 || t == 1) return logo;
          final c = -0.3 + t * 1.6;
          // Kilau putih tipis diagonal, hanya di atas piksel logo.
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: .5),
                Colors.white.withValues(alpha: 0),
              ],
              stops: [
                (c - .1).clamp(0.0, 1.0),
                c.clamp(0.0, 1.0),
                (c + .1).clamp(0.0, 1.0),
              ],
            ).createShader(rect),
            child: logo,
          );
        },
      ),
    ),
  );
}
