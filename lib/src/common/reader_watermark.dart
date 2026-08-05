import 'package:flutter/material.dart';

/// Semi-transparent watermark overlay for trial / DRM-style marking.
class ReaderWatermark extends StatelessWidget {
  const ReaderWatermark({
    super.key,
    required this.text,
    this.opacity = 0.12,
  });

  final String text;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: CustomPaint(
            painter: _WatermarkPainter(text),
          ),
        ),
      ),
    );
  }
}

class _WatermarkPainter extends CustomPainter {
  _WatermarkPainter(this.text);
  final String text;

  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(size.width * 0.15, size.height * 0.2);
    canvas.rotate(-0.4);
    for (var y = 0.0; y < size.height * 1.5; y += 120) {
      for (var x = 0.0; x < size.width * 1.5; x += tp.width + 80) {
        tp.paint(canvas, Offset(x, y));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WatermarkPainter oldDelegate) =>
      oldDelegate.text != text;
}

/// Caps readable pages for preview / trial mode.
int clampTrialPage(int page, int total, int? maxReadablePages) {
  if (maxReadablePages == null || maxReadablePages <= 0) {
    return page.clamp(0, (total - 1).clamp(0, 1 << 30));
  }
  final maxIndex = (maxReadablePages - 1).clamp(0, total - 1);
  return page.clamp(0, maxIndex);
}

int trialPageCount(int total, int? maxReadablePages) {
  if (maxReadablePages == null || maxReadablePages <= 0) return total;
  return maxReadablePages.clamp(0, total);
}
