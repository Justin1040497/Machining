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
    required this.maxLength,
    required this.curveBias,
    this.clipRect,
  });

  final Offset startPoint;
  final Offset targetPoint;
  final double progress;
  final int curveSeed;
  final double arrowHeadScale;
  final Offset strokeOffset;
  final Color color;
  final double maxLength;
  final Offset curveBias;
  final Rect? clipRect;

  @override
  void paint(Canvas canvas, Size size) {
    // 所有提前返回都必须在 canvas.save() 之前，避免 save/restore 不平衡。
    if (progress <= 0 || (targetPoint - startPoint).distance < 1) {
      return;
    }

    final geometry = DoodleArrowGeometry.create(
      startPoint: startPoint,
      targetPoint: targetPoint,
      curveSeed: curveSeed,
      maxLength: maxLength,
      curveBias: curveBias,
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

    canvas.save();

    final safeClipRect = clipRect;
    if (safeClipRect != null && !safeClipRect.isEmpty) {
      canvas.clipRect(safeClipRect);
    }

    final visibleBody = metric.extractPath(0, drawnLength);

    final mainPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final echoPaint = Paint()
      ..color = color.withValues(alpha: color.a * 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.45
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final hatchPaint = Paint()
      ..color = color.withValues(alpha: color.a * 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.translate(strokeOffset.dx, strokeOffset.dy);
    canvas.drawPath(visibleBody, echoPaint);
    canvas.restore();
    canvas.drawPath(visibleBody, mainPaint);

    // 箭头头仅在绘制进度超过 86% 后渐显，避免长线阶段提前出现头部。
    final tangent = metric.getTangentForOffset(drawnLength);
    if (tangent != null && progress >= 0.86) {
      final headProgress = ((progress - 0.86) / 0.14).clamp(0.0, 1.0);
      final head = DoodleArrowGeometry.createArrowHead(
        tip: tangent.position,
        direction: tangent.vector,
        scale: arrowHeadScale * headProgress,
        curveSeed: curveSeed,
      );

      canvas.save();
      canvas.translate(strokeOffset.dx * 0.7, strokeOffset.dy * 0.7);
      canvas.drawPath(head.outline, echoPaint);
      canvas.restore();

      canvas.drawPath(head.outline, mainPaint);
      canvas.drawPath(head.hatching, hatchPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(DoodleArrowPainter oldDelegate) {
    return oldDelegate.startPoint != startPoint ||
        oldDelegate.targetPoint != targetPoint ||
        oldDelegate.progress != progress ||
        oldDelegate.curveSeed != curveSeed ||
        oldDelegate.arrowHeadScale != arrowHeadScale ||
        oldDelegate.strokeOffset != strokeOffset ||
        oldDelegate.color != color ||
        oldDelegate.maxLength != maxLength ||
        oldDelegate.curveBias != curveBias ||
        oldDelegate.clipRect != clipRect;
  }
}
