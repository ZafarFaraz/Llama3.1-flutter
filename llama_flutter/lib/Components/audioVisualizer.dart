import 'dart:math';

import 'package:flutter/material.dart';

class CircularVisualizerPainter extends CustomPainter {
  final double progress; // Represents the progress of the animation
  final int lineCount; // Number of lines/dots around the circle
  final Color startColor;
  final Color endColor;

  CircularVisualizerPainter({
    required this.progress,
    required this.lineCount,
    required this.startColor,
    required this.endColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) * 0.8;

    // Create a gradient for the lines
    final gradient = SweepGradient(
      startAngle: 0.0,
      endAngle: 2 * pi,
      colors: [startColor, endColor],
    );

    final linePaint = Paint()
      ..shader =
          gradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Draw radial lines or dots
    for (int i = 0; i < lineCount; i++) {
      final angle = (i / lineCount) * 2 * pi;
      final x1 = center.dx + radius * cos(angle);
      final y1 = center.dy + radius * sin(angle);
      final x2 = center.dx +
          (radius + progress * 20) *
              cos(angle); // Extend lines based on progress
      final y2 = center.dy + (radius + progress * 20) * sin(angle);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Always repaint to reflect animation changes
  }
}

class CircularVisualizer extends StatefulWidget {
  final bool isListening;
  final bool isResponding;

  const CircularVisualizer(
      {required this.isListening, required this.isResponding});

  @override
  _CircularVisualizerState createState() => _CircularVisualizerState();
}

class _CircularVisualizerState extends State<CircularVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(200, 200),
          painter: CircularVisualizerPainter(
            progress: _controller.value,
            lineCount: 60,
            startColor: widget.isListening ? Colors.blue : Colors.purple,
            endColor: widget.isResponding ? Colors.pink : Colors.green,
          ),
        );
      },
    );
  }
}
