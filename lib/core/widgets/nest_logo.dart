import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// Renders the official OurNest Logo Mark:
/// A nest (horizontal rim plus curved bowl) holding three rounded figures:
/// two parents in teal and a smaller child in coral.
class NestLogoMark extends StatelessWidget {
  final double size;

  const NestLogoMark({super.key, this.size = 80.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _NestLogoPainter(),
      ),
    );
  }
}

class _NestLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Paints
    final tealPaint = Paint()
      ..color = AppColors.primaryTeal
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final coralPaint = Paint()
      ..color = AppColors.accentCoral
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final nestPaint = Paint()
      ..color = AppColors.primaryTealDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final nestRimPaint = Paint()
      ..color = AppColors.primaryTeal
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // 1. Figures inside the nest:
    // Left Parent (Teal)
    final parentRadius = w * 0.12;
    final leftParentHead = Offset(w * 0.32, h * 0.38);
    canvas.drawCircle(leftParentHead, parentRadius, tealPaint);
    // Left Parent body arc/oval
    final leftBodyRect = Rect.fromCenter(
      center: Offset(w * 0.32, h * 0.56),
      width: parentRadius * 2.1,
      height: parentRadius * 2.4,
    );
    canvas.drawOval(leftBodyRect, tealPaint);

    // Right Parent (Teal)
    final rightParentHead = Offset(w * 0.68, h * 0.38);
    canvas.drawCircle(rightParentHead, parentRadius, tealPaint);
    // Right Parent body arc/oval
    final rightBodyRect = Rect.fromCenter(
      center: Offset(w * 0.68, h * 0.56),
      width: parentRadius * 2.1,
      height: parentRadius * 2.4,
    );
    canvas.drawOval(rightBodyRect, tealPaint);

    // Center Child (Warm Coral, slightly smaller)
    final childRadius = w * 0.095;
    final childHead = Offset(w * 0.50, h * 0.44);
    canvas.drawCircle(childHead, childRadius, coralPaint);
    // Child body
    final childBodyRect = Rect.fromCenter(
      center: Offset(w * 0.50, h * 0.60),
      width: childRadius * 2.0,
      height: childRadius * 2.0,
    );
    canvas.drawOval(childBodyRect, coralPaint);

    // 2. Nest Bowl (Curved arc under figures)
    final nestBowl = Path();
    nestBowl.moveTo(w * 0.14, h * 0.62);
    nestBowl.cubicTo(
      w * 0.18, h * 0.90, // control point 1
      w * 0.82, h * 0.90, // control point 2
      w * 0.86, h * 0.62, // end point
    );
    canvas.drawPath(nestBowl, nestPaint);

    // 3. Nest Rim (Horizontal curved line)
    final nestRim = Path();
    nestRim.moveTo(w * 0.10, h * 0.62);
    nestRim.quadraticBezierTo(w * 0.50, h * 0.66, w * 0.90, h * 0.62);
    canvas.drawPath(nestRim, nestRimPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Renders the official OurNest Wordmark:
/// "Our" in deep teal and "Nest" in warm coral, weight 900.
class NestWordmark extends StatelessWidget {
  final double fontSize;

  const NestWordmark({super.key, this.fontSize = 38.0});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Our',
            style: GoogleFonts.nunito(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: AppColors.primaryTeal,
              letterSpacing: -0.5,
            ),
          ),
          TextSpan(
            text: 'Nest',
            style: GoogleFonts.nunito(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: AppColors.accentCoral,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}
