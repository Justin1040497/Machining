import 'package:flutter/material.dart';
import 'package:framelean/features/workbench/guide/arrow/doodle_arrow_geometry.dart';

class DoodleArrowPainter extends CustomPainter {
  const DoodleArrowPainter({
    required this.startPoint,
    required this.targetPoint,
    required this.progress,
    required this.curveSeed,
    required this.arrowHeadScale,
    required this.strokeOffset,
    required this.color,
  });

  final Offset startPoint;
  final Offset targetPoint;
  final double progress;
  final int curveSeed;
  final double arrowHeadScale;
  final Offset strokeOffset;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || (targetPoint - startPoint).distance < 1) {
      return;
    }
    final geometry = DoodleArrowGeometry.create(
      startPoint: startPoint,
      targetPoint: targetPoint,
      curveSeed: curveSeed,
    );
    final metrics = geometry.body.computeMetrics().toList(growable: false);
    if (metrics.isEmpty) {
      return;
    }
    final metric = metrics.first;
    final drawnLength = metric.length * progress.clamp(0.0, 1.0);
    if (drawnLength <= 0) {
      return;
    }
    final visibleBody = metric.extractPath(0, drawnLength);
    final mainPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final echoPaint = Paint()
      ..color = color.withValues(alpha: color.a * 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.translate(strokeOffset.dx, strokeOffset.dy);
    canvas.drawPath(visibleBody, echoPaint);
    canvas.restore();
    canvas.drawPath(visibleBody, mainPaint);

    final tangent = metric.getTangentForOffset(drawnLength);
    if (tangent == null || progress < 0.86) {
      return;
    }
    final headProgress = ((progress - 0.86) / 0.14).clamp(0.0, 1.0);
    final head = DoodleArrowGeometry.createArrowHead(
      tip: tangent.position,
      direction: tangent.vector,
      scale: arrowHeadScale * headProgress,
      curveSeed: curveSeed,
    );
    canvas.save();
    canvas.translate(strokeOffset.dx * 0.7, strokeOffset.dy * 0.7);
    canvas.drawPath(head, echoPaint);
    canvas.restore();
    canvas.drawPath(head, mainPaint);
  }

  @override
  bool shouldRepaint(DoodleArrowPainter oldDelegate) {
    return oldDelegate.startPoint != startPoint ||
        oldDelegate.targetPoint != targetPoint ||
        oldDelegate.progress != progress ||
        oldDelegate.curveSeed != curveSeed ||
        oldDelegate.arrowHeadScale != arrowHeadScale ||
        oldDelegate.strokeOffset != strokeOffset ||
        oldDelegate.color != color;
  }
}
