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

/// 开放式涂鸦箭头头，由两条不对称外轮廓线与两条内部排线组成。
///
/// 不填充、不调用 [Path.close]，以保留参考图中的手绘批注感。
class DoodleArrowHead {
  const DoodleArrowHead({required this.outline, required this.hatching});

  final Path outline;
  final Path hatching;
}

abstract final class DoodleArrowGeometry {
  static DoodleArrowPath create({
    required Offset startPoint,
    required Offset targetPoint,
    required int curveSeed,
    required double maxLength,
    required Offset curveBias,
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

    // 随机只影响小幅法向扰动，最大不超过 8 px，避免回头或自相交。
    final randomLimit = math.min(8.0, distance * 0.035);

    final jitter1 = _range(random, -randomLimit, randomLimit);
    final jitter2 = _range(random, -randomLimit, randomLimit);

    final controlPoint1 =
        effectiveStart +
        direction * (distance * 0.30) +
        curveBias * 0.55 +
        normal * jitter1;

    final controlPoint2 =
        effectiveStart +
        direction * (distance * 0.72) +
        curveBias +
        normal * jitter2;

    // 单条三次贝塞尔曲线，更接近随手画出的浅弧，也更容易保证不绕回目标。
    final path = Path()
      ..moveTo(effectiveStart.dx, effectiveStart.dy)
      ..cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        targetPoint.dx,
        targetPoint.dy,
      );

    return DoodleArrowPath(
      body: path,
      start: effectiveStart,
      controlPoint1: controlPoint1,
      controlPoint2: controlPoint2,
      target: targetPoint,
    );
  }

  /// 绘制带内部排线的开放式涂鸦箭头头。
  ///
  /// [direction] 为曲线末端切线方向，[scale] 同时承载绘制进度与每支箭头的
  /// 随机缩放（0.8..1.2），最终箭头头长度约 12～17 px。
  static DoodleArrowHead createArrowHead({
    required Offset tip,
    required Offset direction,
    required double scale,
    required int curveSeed,
  }) {
    final length = direction.distance;

    if (length < 0.1) {
      return DoodleArrowHead(outline: Path(), hatching: Path());
    }

    final unit = direction / length;
    final back = -unit;
    final normal = Offset(-unit.dy, unit.dx);
    final random = math.Random(curveSeed ^ 0x5f3759df);

    final headLength = 14.5 * scale;

    final upperWidth = headLength * _range(random, 0.48, 0.60);
    final lowerWidth = headLength * _range(random, 0.40, 0.54);

    final upper = tip + back * headLength + normal * upperWidth;
    final lower = tip + back * (headLength * 0.90) - normal * lowerWidth;

    // 两条不完全对称的外轮廓线，均止于 tip，不闭合也不填充。
    final outline = Path()
      ..moveTo(upper.dx, upper.dy)
      ..quadraticBezierTo(
        Offset.lerp(upper, tip, 0.58)!.dx + normal.dx * 0.7,
        Offset.lerp(upper, tip, 0.58)!.dy + normal.dy * 0.7,
        tip.dx,
        tip.dy,
      )
      ..moveTo(lower.dx, lower.dy)
      ..quadraticBezierTo(
        Offset.lerp(lower, tip, 0.55)!.dx - normal.dx * 0.5,
        Offset.lerp(lower, tip, 0.55)!.dy - normal.dy * 0.5,
        tip.dx,
        tip.dy,
      );

    // 两条简短的内部排线，增强手绘批注感。
    final hatchStart1 = Offset.lerp(upper, tip, 0.42)!;
    final hatchEnd1 = Offset.lerp(upper, lower, 0.58)!;

    final hatchStart2 = Offset.lerp(lower, tip, 0.44)!;
    final hatchEnd2 = Offset.lerp(upper, lower, 0.42)!;

    final hatching = Path()
      ..moveTo(hatchStart1.dx, hatchStart1.dy)
      ..lineTo(hatchEnd1.dx, hatchEnd1.dy)
      ..moveTo(hatchStart2.dx, hatchStart2.dy)
      ..lineTo(hatchEnd2.dx, hatchEnd2.dy);

    return DoodleArrowHead(outline: outline, hatching: hatching);
  }

  static double _range(math.Random random, double minimum, double maximum) {
    if (maximum <= minimum) {
      return minimum;
    }
    return minimum + random.nextDouble() * (maximum - minimum);
  }
}
