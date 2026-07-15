import 'package:flutter/material.dart';
import 'package:framelean/features/workbench/guide/arrow/doodle_arrow_geometry.dart';
import 'package:framelean/features/workbench/guide/models/guide_geometry.dart';

class TaskWorkspaceGuideLayout {
  const TaskWorkspaceGuideLayout._({
    required this.capacity,
    this.taskOperation,
    this.startAll,
  });

  static const double laneGap = 28;
  static const double _minimumTaskLaneHeight = 152;
  static const double _minimumStartLaneHeight = 180;

  final TaskWorkspaceGuideCapacity capacity;
  final TaskOperationGuidePlacement? taskOperation;
  final StartAllGuidePlacement? startAll;

  static TaskWorkspaceGuideLayout resolve(GuideGeometry geometry) {
    final safeRect = geometry.taskWorkspaceGuideRect;
    if (geometry.taskWorkspaceGuideCapacity ==
            TaskWorkspaceGuideCapacity.hidden ||
        safeRect.isEmpty) {
      return const TaskWorkspaceGuideLayout._(
        capacity: TaskWorkspaceGuideCapacity.hidden,
      );
    }

    if (geometry.taskWorkspaceGuideCapacity ==
        TaskWorkspaceGuideCapacity.both) {
      final extraHeight =
          safeRect.height -
          (_minimumTaskLaneHeight + laneGap + _minimumStartLaneHeight);
      final taskLaneHeight = _minimumTaskLaneHeight + extraHeight * 0.45;
      final taskLane = Rect.fromLTRB(
        safeRect.left,
        safeRect.top,
        safeRect.right,
        safeRect.top + taskLaneHeight,
      );
      final startLane = Rect.fromLTRB(
        safeRect.left,
        taskLane.bottom + laneGap,
        safeRect.right,
        safeRect.bottom,
      );
      final taskPlacement = TaskOperationGuidePlacement.resolve(
        geometry: geometry,
        lane: taskLane,
      );
      final startPlacement = StartAllGuidePlacement.resolve(
        geometry: geometry,
        lane: startLane,
      );
      if (taskPlacement != null &&
          startPlacement != null &&
          !taskPlacement.visualRect.overlaps(startPlacement.visualRect)) {
        return TaskWorkspaceGuideLayout._(
          capacity: TaskWorkspaceGuideCapacity.both,
          taskOperation: taskPlacement,
          startAll: startPlacement,
        );
      }
    }

    final startPlacement = StartAllGuidePlacement.resolve(
      geometry: geometry,
      lane: safeRect,
    );
    if (startPlacement != null) {
      return TaskWorkspaceGuideLayout._(
        capacity: TaskWorkspaceGuideCapacity.startAllOnly,
        startAll: startPlacement,
      );
    }
    return const TaskWorkspaceGuideLayout._(
      capacity: TaskWorkspaceGuideCapacity.hidden,
    );
  }
}

class TaskOperationGuidePlacement {
  const TaskOperationGuidePlacement._({
    required this.lane,
    required this.arrowStart,
    required this.arrowTarget,
    required this.textRect,
    required this.visualRect,
  });

  static const int arrowSeed = 1401;
  static const double maxArrowLength = 245;
  static const Offset curveBias = Offset(0, 72);
  static const Offset targetDirection = Offset(0, -1);
  static const double textWidth = 210;
  static const double textHeight = 42;
  static const double tailGap = 14;

  final Rect lane;
  final Offset arrowStart;
  final Offset arrowTarget;
  final Rect textRect;
  final Rect visualRect;

  static TaskOperationGuidePlacement? resolve({
    required GuideGeometry geometry,
    required Rect lane,
  }) {
    final lastTaskRect = geometry.lastTaskRect;
    if (lastTaskRect == null || lane.isEmpty) {
      return null;
    }
    final arrowTarget = Offset(lastTaskRect.right - 42, lane.top + 20);
    final arrowSpan = (geometry.workbenchSize.width * 0.18)
        .clamp(185.0, 220.0)
        .toDouble();
    final arrowStart = Offset(arrowTarget.dx - arrowSpan, lane.top + 56);
    final textLeft = arrowStart.dx - textWidth - tailGap;
    final textRect = Rect.fromLTWH(
      textLeft,
      arrowStart.dy - 20,
      textWidth,
      textHeight,
    );
    final arrowRect = _arrowVisualRect(
      startPoint: arrowStart,
      targetPoint: arrowTarget,
      curveSeed: arrowSeed,
      maxLength: maxArrowLength,
      curveBias: curveBias,
      targetDirection: targetDirection,
    );
    final visualRect = arrowRect.expandToInclude(textRect);
    if (!_containsRect(lane, visualRect)) {
      return null;
    }
    return TaskOperationGuidePlacement._(
      lane: lane,
      arrowStart: arrowStart,
      arrowTarget: arrowTarget,
      textRect: textRect,
      visualRect: visualRect,
    );
  }
}

class StartAllGuidePlacement {
  const StartAllGuidePlacement._({
    required this.lane,
    required this.arrowStart,
    required this.arrowTarget,
    required this.textRect,
    required this.visualRect,
  });

  static const int arrowSeed = 2803;
  static const double maxArrowLength = 245;
  static const Offset curveBias = Offset(0, -72);
  static const Offset targetDirection = Offset(0, 1);
  static const double textWidth = 112;
  static const double textHeight = 22;
  static const double tailGap = 14;

  final Rect lane;
  final Offset arrowStart;
  final Offset arrowTarget;
  final Rect textRect;
  final Rect visualRect;

  static StartAllGuidePlacement? resolve({
    required GuideGeometry geometry,
    required Rect lane,
  }) {
    final buttonRect = geometry.startButtonRect;
    if (buttonRect.isEmpty || lane.isEmpty) {
      return null;
    }
    final arrowTarget = Offset(buttonRect.center.dx, buttonRect.top - 30);
    final arrowStart = arrowTarget + const Offset(196, -82);
    final textRect = Rect.fromLTWH(
      arrowStart.dx + tailGap,
      arrowStart.dy - 10,
      textWidth,
      textHeight,
    );
    final arrowRect = _arrowVisualRect(
      startPoint: arrowStart,
      targetPoint: arrowTarget,
      curveSeed: arrowSeed,
      maxLength: maxArrowLength,
      curveBias: curveBias,
      targetDirection: targetDirection,
    );
    final visualRect = arrowRect.expandToInclude(textRect);
    if (!_containsRect(lane, visualRect)) {
      return null;
    }
    return StartAllGuidePlacement._(
      lane: lane,
      arrowStart: arrowStart,
      arrowTarget: arrowTarget,
      textRect: textRect,
      visualRect: visualRect,
    );
  }
}

Rect _arrowVisualRect({
  required Offset startPoint,
  required Offset targetPoint,
  required int curveSeed,
  required double maxLength,
  required Offset curveBias,
  required Offset targetDirection,
}) {
  final geometry = DoodleArrowGeometry.create(
    startPoint: startPoint,
    targetPoint: targetPoint,
    curveSeed: curveSeed,
    maxLength: maxLength,
    curveBias: curveBias,
    targetDirection: targetDirection,
  );
  var bounds = geometry.body.getBounds();
  final metrics = geometry.body.computeMetrics().toList(growable: false);
  if (metrics.isNotEmpty) {
    final metric = metrics.first;
    final tangent = metric.getTangentForOffset(metric.length);
    if (tangent != null) {
      final head = DoodleArrowGeometry.createArrowHead(
        tip: tangent.position,
        direction: tangent.vector,
        bodyLength: metric.length,
        scale: 1.06,
        curveSeed: curveSeed,
      );
      bounds = bounds
          .expandToInclude(head.outline.getBounds())
          .expandToInclude(head.emphasis.getBounds());
    }
  }
  return bounds.inflate(3);
}

bool _containsRect(Rect outer, Rect inner) {
  const tolerance = 0.5;
  return inner.left >= outer.left - tolerance &&
      inner.top >= outer.top - tolerance &&
      inner.right <= outer.right + tolerance &&
      inner.bottom <= outer.bottom + tolerance;
}
