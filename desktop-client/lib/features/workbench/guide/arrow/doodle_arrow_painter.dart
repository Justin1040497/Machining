import 'dart:math' as math;
import 'dart:ui' show PathMetric;

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
    this.targetDirection,
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
  final Offset? targetDirection;
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
      targetDirection: targetDirection,
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

    final tangent = metric.getTangentForOffset(drawnLength);
    DoodleArrowHead? head;
    if (tangent != null && progress >= 0.82) {
      final headProgress = ((progress - 0.82) / 0.18).clamp(0.0, 1.0);
      head = DoodleArrowGeometry.createArrowHead(
        tip: tangent.position,
        direction: tangent.vector,
        bodyLength: metric.length,
        scale: arrowHeadScale * headProgress,
        curveSeed: curveSeed,
      );
    }

    final bodyEndLength = math.max(
      0.0,
      drawnLength - (head?.length ?? 0) * 0.66,
    );
    final visibleBody = metric.extractPath(0, bodyEndLength);
    if (head != null && bodyEndLength > 0) {
      final shaftEndTangent = metric.getTangentForOffset(bodyEndLength);
      if (shaftEndTangent != null) {
        final shaftEnd = shaftEndTangent.position;
        final shaftDirection = shaftEndTangent.vector.distance < 0.1
            ? head.direction
            : shaftEndTangent.vector / shaftEndTangent.vector.distance;
        final connectorDistance = (head.baseNotch - shaftEnd).distance;
        if (connectorDistance < 0.5) {
          visibleBody.lineTo(head.baseNotch.dx, head.baseNotch.dy);
        } else {
          final firstHandleLength = math.min(12.0, connectorDistance * 0.38);
          final secondHandleLength = math.min(12.0, connectorDistance * 0.38);
          final firstControl = shaftEnd + shaftDirection * firstHandleLength;
          final secondControl =
              head.baseNotch - head.direction * secondHandleLength;
          visibleBody.cubicTo(
            firstControl.dx,
            firstControl.dy,
            secondControl.dx,
            secondControl.dy,
            head.baseNotch.dx,
            head.baseNotch.dy,
          );
        }
      }
    }

    final mainPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final echoPaint = Paint()
      ..color = color.withValues(alpha: color.a * 0.46)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final texturePaint = Paint()
      ..color = color.withValues(alpha: color.a * 0.64)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final hatchPaint = Paint()
      ..color = color.withValues(alpha: color.a * 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..color = color.withValues(alpha: color.a * 0.28)
      ..style = PaintingStyle.fill;
    final emphasisPaint = Paint()
      ..color = color.withValues(alpha: color.a * 0.64)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.translate(strokeOffset.dx, strokeOffset.dy);
    canvas.drawPath(visibleBody, echoPaint);
    canvas.restore();
    canvas.drawPath(visibleBody, mainPaint);
    _drawPencilTexture(
      canvas: canvas,
      metric: metric,
      drawnLength: bodyEndLength,
      curveSeed: curveSeed,
      paint: texturePaint,
    );

    // The larger sketch head begins slightly earlier so its outline and inner
    // hatching read as one continuous hand-drawn finish.
    if (head != null) {
      canvas.drawPath(head.outline, fillPaint);
      canvas.save();
      canvas.translate(strokeOffset.dx * 0.7, strokeOffset.dy * 0.7);
      canvas.drawPath(head.outline, echoPaint);
      canvas.restore();

      canvas.drawPath(head.outline, mainPaint);
      canvas.drawPath(head.hatching, hatchPaint);
      if (progress >= 0.90) {
        final emphasisProgress = ((progress - 0.90) / 0.10).clamp(0.0, 1.0);
        for (final emphasisMetric in head.emphasis.computeMetrics()) {
          canvas.drawPath(
            emphasisMetric.extractPath(
              0,
              emphasisMetric.length * emphasisProgress,
            ),
            emphasisPaint,
          );
        }
      }
    }

    canvas.restore();
  }

  void _drawPencilTexture({
    required Canvas canvas,
    required PathMetric metric,
    required double drawnLength,
    required int curveSeed,
    required Paint paint,
  }) {
    if (drawnLength < 12) {
      return;
    }
    final random = math.Random(curveSeed ^ 0x4a11ce);
    final segmentCount = (metric.length / 38).round().clamp(4, 10);
    for (var index = 0; index < segmentCount; index += 1) {
      final baseOffset = metric.length * (0.06 + 0.88 * index / segmentCount);
      final start = math.min(drawnLength, baseOffset + _range(random, -5, 5));
      final end = math.min(drawnLength, start + _range(random, 10, 25));
      if (end - start < 3) {
        continue;
      }
      final texture = metric.extractPath(start, end);
      canvas.save();
      canvas.translate(_range(random, -1.1, 1.1), _range(random, -1.1, 1.1));
      canvas.drawPath(texture, paint);
      canvas.restore();
    }
  }

  double _range(math.Random random, double minimum, double maximum) {
    return minimum + random.nextDouble() * (maximum - minimum);
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
        oldDelegate.targetDirection != targetDirection ||
        oldDelegate.clipRect != clipRect;
  }
}
