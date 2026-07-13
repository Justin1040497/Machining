import 'dart:math' as math;

import 'package:flutter/material.dart';

class DoodleArrowPath {
  const DoodleArrowPath({
    required this.body,
    required this.start,
    required this.controlPoint1,
    required this.controlPoint2,
    required this.target,
  });

  final Path body;
  final Offset start;
  final Offset controlPoint1;
  final Offset controlPoint2;
  final Offset target;
}

abstract final class DoodleArrowGeometry {
  static DoodleArrowPath create({
    required Offset startPoint,
    required Offset targetPoint,
    required int curveSeed,
  }) {
    final delta = targetPoint - startPoint;
    final distance = delta.distance;
    if (distance < 1) {
      final path = Path()
        ..moveTo(startPoint.dx, startPoint.dy)
        ..lineTo(targetPoint.dx, targetPoint.dy);
      return DoodleArrowPath(
        body: path,
        start: startPoint,
        controlPoint1: startPoint,
        controlPoint2: targetPoint,
        target: targetPoint,
      );
    }

    final direction = delta / distance;
    final normal = Offset(-direction.dy, direction.dx);
    final random = math.Random(curveSeed);
    final maximumOffset = math.min(42.0, distance * 0.16);
    final minimumOffset = math.min(10.0, maximumOffset);
    final middleMagnitude = _range(random, minimumOffset, maximumOffset);
    final directionSign = random.nextBool() ? 1.0 : -1.0;
    final middleOffset = middleMagnitude * directionSign;
    final firstOffset = middleOffset * _range(random, 0.48, 0.72);
    final secondOffset = -middleOffset * _range(random, 0.28, 0.52);

    // Every point advances monotonically toward the target. Randomness is only
    // applied on the normal axis, preventing loops and backward turns while the
    // two cubic segments create a broad, low-frequency hand-drawn wave.
    final controlPoint1 =
        startPoint + direction * (distance * 0.18) + normal * firstOffset;
    final controlPoint2 =
        startPoint +
        direction * (distance * 0.38) +
        normal * (middleOffset * 1.08);
    final middlePoint =
        startPoint + direction * (distance * 0.52) + normal * middleOffset;
    final controlPoint3 =
        startPoint +
        direction * (distance * 0.68) +
        normal * (middleOffset * 0.72);
    final controlPoint4 =
        startPoint + direction * (distance * 0.86) + normal * secondOffset;
    final path = Path()
      ..moveTo(startPoint.dx, startPoint.dy)
      ..cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        middlePoint.dx,
        middlePoint.dy,
      )
      ..cubicTo(
        controlPoint3.dx,
        controlPoint3.dy,
        controlPoint4.dx,
        controlPoint4.dy,
        targetPoint.dx,
        targetPoint.dy,
      );

    return DoodleArrowPath(
      body: path,
      start: startPoint,
      controlPoint1: controlPoint1,
      controlPoint2: controlPoint2,
      target: targetPoint,
    );
  }

  static Path createArrowHead({
    required Offset tip,
    required Offset direction,
    required double scale,
    required int curveSeed,
  }) {
    final length = direction.distance;
    if (length < 0.1) {
      return Path();
    }
    final unit = direction / length;
    final back = -unit;
    final normal = Offset(-unit.dy, unit.dx);
    final random = math.Random(curveSeed ^ 0x5f3759df);
    final headLength = 16 * scale;
    final upperWidth = headLength * _range(random, 0.46, 0.58);
    final lowerWidth = headLength * _range(random, 0.39, 0.52);
    final upper = tip + back * headLength + normal * upperWidth;
    final lower = tip + back * (headLength * 0.92) - normal * lowerWidth;
    final upperControl = Offset.lerp(upper, tip, 0.58)! + normal * 0.8;
    final lowerControl = Offset.lerp(lower, tip, 0.55)! - normal * 0.6;

    return Path()
      ..moveTo(upper.dx, upper.dy)
      ..quadraticBezierTo(upperControl.dx, upperControl.dy, tip.dx, tip.dy)
      ..moveTo(lower.dx, lower.dy)
      ..quadraticBezierTo(lowerControl.dx, lowerControl.dy, tip.dx, tip.dy);
  }

  static double _range(math.Random random, double minimum, double maximum) {
    if (maximum <= minimum) {
      return minimum;
    }
    return minimum + random.nextDouble() * (maximum - minimum);
  }
}
