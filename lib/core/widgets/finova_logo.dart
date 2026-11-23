import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../app/theme/app_colors.dart';

export 'finova_splash.dart';

const finovaLogoAsset = 'assets/images/finova_logo.svg';

/// Logo Finova (SVG) dengan teks "finova" di sampingnya.
class FinovaBrand extends StatelessWidget {
  const FinovaBrand({super.key, this.logoSize = 42, this.fontSize = 28});
  final double logoSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SvgPicture.asset(
        finovaLogoAsset,
        width: logoSize,
        height: logoSize,
        semanticsLabel: 'Logo Finova',
      ),
      const SizedBox(width: 12),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'finova',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              color: AppColors.text,
            ),
          ),
        ),
      ),
    ],
  );
}
