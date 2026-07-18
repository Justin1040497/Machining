import 'dart:math' as math;

import 'package:flutter/material.dart';

class DoodleArrowPath {
  const DoodleArrowPath({
    required this.body,
    required this.start,
    required this.controlPoint1,
    required this.controlPoint2,
    required this.middlePoint,
    required this.controlPoint3,
    required this.controlPoint4,
    required this.target,
  });

  final Path body;
  final Offset start;
  final Offset controlPoint1;
  final Offset controlPoint2;
  final Offset middlePoint;
  final Offset controlPoint3;
  final Offset controlPoint4;
  final Offset target;
}

/// 封闭式涂鸦箭头头，由不对称轮廓、内部排线和末端强调线组成。
class DoodleArrowHead {
  const DoodleArrowHead({
    required this.outline,
    required this.hatching,
    required this.emphasis,
    required this.length,
    required this.baseNotch,
    required this.direction,
  });

  final Path outline;
  final Path hatching;
  final Path emphasis;
  final double length;
  final Offset baseNotch;
  final Offset direction;
}

abstract final class DoodleArrowGeometry {
  static DoodleArrowPath create({
    required Offset startPoint,
    required Offset targetPoint,
    required int curveSeed,
    required double maxLength,
    required Offset curveBias,
    Offset? targetDirection,
  }) {
    final rawDelta = targetPoint - startPoint;
    final rawDistance = rawDelta.distance;

    if (rawDistance < 1) {
      final path = Path()
        ..moveTo(startPoint.dx, startPoint.dy)
        ..lineTo(targetPoint.dx, targetPoint.dy);

      return DoodleArrowPath(
        body: path,
        start: startPoint,
        controlPoint1: startPoint,
        controlPoint2: targetPoint,
        middlePoint: Offset.lerp(startPoint, targetPoint, 0.5)!,
        controlPoint3: startPoint,
        controlPoint4: targetPoint,
        target: targetPoint,
      );
    }

    final rawDirection = rawDelta / rawDistance;
    final safeMaxLength = math.max(40.0, maxLength);

    // 当起点与终点距离超过最大长度时，终点保持不动，沿“终点指向起点”的
    // 方向把实际绘制起点向终点收缩，只绘制末端最长 maxLength 的一段。
    final effectiveStart = rawDistance > safeMaxLength
        ? targetPoint - rawDirection * safeMaxLength
        : startPoint;

    final delta = targetPoint - effectiveStart;
    final distance = delta.distance;
    final direction = delta / distance;
    final normal = Offset(-direction.dy, direction.dx);

    final random = math.Random(curveSeed);

    // curveBias only contributes on the normal axis. Every control point keeps
    // moving forward along the arrow direction, so the two cubics cannot turn
    // back even when the window changes shape.
    final projectedBias = curveBias.dx * normal.dx + curveBias.dy * normal.dy;
    final preferredMagnitude = (distance * 0.085).clamp(13.0, 25.0);
    final biasSign = projectedBias.abs() >= 2
        ? projectedBias.sign
        : (random.nextBool() ? 1.0 : -1.0);
    final biasMagnitude = math
        .max(projectedBias.abs(), preferredMagnitude)
        .clamp(12.0, math.min(76.0, distance * 0.38));
    final signedBias = biasSign * biasMagnitude;
    final jitterLimit = math.min(3.2, distance * 0.015);
    final jitter1 = _range(random, -jitterLimit, jitterLimit);
    final jitter2 = _range(random, -jitterLimit, jitterLimit);
    final jitter3 = _range(random, -jitterLimit, jitterLimit);
    final jitter4 = _range(random, -jitterLimit, jitterLimit);

    final controlPoint1 =
        effectiveStart +
        direction * (distance * 0.17) +
        normal * (signedBias * 0.42 + jitter1);

    final controlPoint2 =
        effectiveStart +
        direction * (distance * 0.38) +
        normal * (signedBias * 1.08 + jitter2);

    final middlePoint =
        effectiveStart +
        direction * (distance * 0.52) +
        normal * (signedBias + jitter3 * 0.5);

    final controlPoint3 =
        effectiveStart +
        direction * (distance * 0.67) +
        normal * (signedBias * 0.90 + jitter3 * 0.5);

    final requestedTargetDirection = targetDirection;
    final controlPoint4 =
        requestedTargetDirection != null &&
            requestedTargetDirection.distance >= 0.1
        ? targetPoint -
              requestedTargetDirection /
                  requestedTargetDirection.distance *
                  math.min(34.0, distance * 0.16)
        : effectiveStart +
              direction * (distance * 0.86) +
              normal * (-signedBias * 0.26 + jitter4);

    // Two connected cubics create the broad S-shaped gesture from the visual
    // reference while preserving a stable final tangent for the arrowhead.
    final path = Path()
      ..moveTo(effectiveStart.dx, effectiveStart.dy)
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
      start: effectiveStart,
      controlPoint1: controlPoint1,
      controlPoint2: controlPoint2,
      middlePoint: middlePoint,
      controlPoint3: controlPoint3,
      controlPoint4: controlPoint4,
      target: targetPoint,
    );
  }

  /// 绘制带内部排线的封闭式涂鸦箭头头。
  ///
  /// [direction] 为曲线末端切线方向，[bodyLength] 用于把最终头部限制在
  /// 约 23～30 px，[scale] 同时承载绘制进度与轻微的 seeded 缩放。
  static DoodleArrowHead createArrowHead({
    required Offset tip,
    required Offset direction,
    required double bodyLength,
    required double scale,
    required int curveSeed,
  }) {
    final length = direction.distance;

    if (length < 0.1) {
      return DoodleArrowHead(
        outline: Path(),
        hatching: Path(),
        emphasis: Path(),
        length: 0,
        baseNotch: tip,
        direction: Offset.zero,
      );
    }

    final unit = direction / length;
    final back = -unit;
    final normal = Offset(-unit.dy, unit.dx);
    final random = math.Random(curveSeed ^ 0x5f3759df);

    final baseHeadLength = (bodyLength * 0.11).clamp(24.0, 28.0);
    final headLength = baseHeadLength * scale;
    final upperWidth = headLength * _range(random, 0.50, 0.58);
    final lowerWidth = headLength * _range(random, 0.44, 0.53);
    final upper = tip + back * headLength + normal * upperWidth;
    final lower =
        tip +
        back * (headLength * _range(random, 0.88, 0.95)) -
        normal * lowerWidth;
    // The notch stays exactly on the arrow axis, centered between the two
    // asymmetric wings.
    final baseNotch = tip + back * (headLength * 0.58);

    // A slightly concave, closed paper-plane silhouette is much closer to the
    // reference than the previous standard two-line arrowhead.
    final outline = Path()
      ..moveTo(tip.dx, tip.dy)
      ..quadraticBezierTo(
        Offset.lerp(tip, upper, 0.54)!.dx + normal.dx * 0.8,
        Offset.lerp(tip, upper, 0.54)!.dy + normal.dy * 0.8,
        upper.dx,
        upper.dy,
      )
      ..quadraticBezierTo(
        Offset.lerp(upper, baseNotch, 0.55)!.dx,
        Offset.lerp(upper, baseNotch, 0.55)!.dy,
        baseNotch.dx,
        baseNotch.dy,
      )
      ..quadraticBezierTo(
        Offset.lerp(baseNotch, lower, 0.54)!.dx,
        Offset.lerp(baseNotch, lower, 0.54)!.dy,
        lower.dx,
        lower.dy,
      )
      ..quadraticBezierTo(
        Offset.lerp(lower, tip, 0.48)!.dx - normal.dx * 0.6,
        Offset.lerp(lower, tip, 0.48)!.dy - normal.dy * 0.6,
        tip.dx,
        tip.dy,
      )
      ..close();

    final hatching = Path();
    for (var index = 0; index < 3; index += 1) {
      final fraction = 0.24 + index * 0.18;
      final hatchStart = Offset.lerp(upper, tip, fraction)!;
      final hatchEnd = Offset.lerp(
        baseNotch,
        Offset.lerp(lower, tip, 0.72)!,
        (fraction + 0.12).clamp(0.0, 1.0),
      )!;
      hatching
        ..moveTo(hatchStart.dx, hatchStart.dy)
        ..lineTo(hatchEnd.dx, hatchEnd.dy);
    }

    // Three short rays beyond the tip reproduce the annotated emphasis from
    // the reference. The caller clips them to each group's safe background.
    final emphasis = Path();
    final rayOffsets = <double>[-1, 0, 1];
    for (final rayOffset in rayOffsets) {
      final rayStart =
          tip + unit * (8 + rayOffset.abs()) + normal * rayOffset * 7;
      final rayEnd =
          tip + unit * (17 - rayOffset.abs()) + normal * rayOffset * 12;
      emphasis
        ..moveTo(rayStart.dx, rayStart.dy)
        ..lineTo(rayEnd.dx, rayEnd.dy);
    }

    return DoodleArrowHead(
      outline: outline,
      hatching: hatching,
      emphasis: emphasis,
      length: headLength,
      baseNotch: baseNotch,
      direction: unit,
    );
  }

  static double _range(math.Random random, double minimum, double maximum) {
    if (maximum <= minimum) {
      return minimum;
    }
    return minimum + random.nextDouble() * (maximum - minimum);
  }
}
