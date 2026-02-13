import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final Color color;
  final Color backgroundColor;
  final double barWidth;
  final double barSpacing;

  WaveformPainter({
    required this.amplitudes,
    this.color = AppColors.primary,
    this.backgroundColor = AppColors.surfaceVariant,
    this.barWidth = 3.0,
    this.barSpacing = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    final centerY = size.height / 2;
    final totalBarWidth = barWidth + barSpacing;
    final maxBars = (size.width / totalBarWidth).floor();
    final startIndex = max(0, amplitudes.length - maxBars);
    final visibleAmps = amplitudes.sublist(startIndex);

    for (var i = 0; i < visibleAmps.length; i++) {
      final x = i * totalBarWidth + barWidth / 2;
      if (x > size.width) break;

      final amplitude = visibleAmps[i].clamp(0.05, 1.0);
      final barHeight = amplitude * (size.height * 0.8);

      paint.color = color;
      canvas.drawLine(
        Offset(x, centerY - barHeight / 2),
        Offset(x, centerY + barHeight / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return amplitudes.length != oldDelegate.amplitudes.length ||
        (amplitudes.isNotEmpty &&
            oldDelegate.amplitudes.isNotEmpty &&
            amplitudes.last != oldDelegate.amplitudes.last);
  }
}

class LiveWaveform extends StatelessWidget {
  final List<double> amplitudes;
  final double height;
  final Color? color;

  const LiveWaveform({
    super.key,
    required this.amplitudes,
    this.height = 120,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: WaveformPainter(
          amplitudes: amplitudes,
          color: color ?? AppColors.primary,
        ),
      ),
    );
  }
}
