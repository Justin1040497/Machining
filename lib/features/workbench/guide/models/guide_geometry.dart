import 'dart:math' as math;

import 'package:flutter/material.dart';

class GuideGeometry {
  const GuideGeometry({
    required this.workbenchSize,
    required this.listViewportRect,
    required this.addButtonRect,
    required this.startButtonRect,
    required this.hasScrollableContent,
    this.lastTaskRect,
  });

  static const double minimumTaskWorkspaceGuideHeight = 180;
  static const double dualTaskWorkspaceGuideHeight = 360;

  final Size workbenchSize;
  final Rect listViewportRect;
  final Rect? lastTaskRect;
  final Rect addButtonRect;
  final Rect startButtonRect;
  final bool hasScrollableContent;

  double get taskGuideHeight {
    final taskRect = lastTaskRect;
    if (taskRect == null) {
      return 0;
    }
    return listViewportRect.bottom - taskRect.bottom;
  }

  Rect get taskWorkspaceGuideRect {
    final taskRect = lastTaskRect;
    if (taskRect == null || startButtonRect.isEmpty) {
      return Rect.zero;
    }
    final top = taskRect.bottom + 16;
    final bottom = math.min(listViewportRect.bottom, startButtonRect.top - 10);
    if (bottom <= top) {
      return Rect.zero;
    }
    return Rect.fromLTRB(
      listViewportRect.left,
      top,
      listViewportRect.right,
      bottom,
    );
  }

  bool get hasTaskAnchors => lastTaskRect != null && !startButtonRect.isEmpty;

  TaskWorkspaceGuideCapacity get taskWorkspaceGuideCapacity {
    if (!hasTaskAnchors || hasScrollableContent) {
      return TaskWorkspaceGuideCapacity.hidden;
    }
    final height = taskWorkspaceGuideRect.height;
    if (height >= dualTaskWorkspaceGuideHeight) {
      return TaskWorkspaceGuideCapacity.both;
    }
    if (height >= minimumTaskWorkspaceGuideHeight) {
      return TaskWorkspaceGuideCapacity.startAllOnly;
    }
    return TaskWorkspaceGuideCapacity.hidden;
  }

  bool get canShowEmptyQueueGuide => !addButtonRect.isEmpty;

  @override
  bool operator ==(Object other) {
    return other is GuideGeometry &&
        other.workbenchSize == workbenchSize &&
        other.listViewportRect == listViewportRect &&
        other.lastTaskRect == lastTaskRect &&
        other.addButtonRect == addButtonRect &&
        other.startButtonRect == startButtonRect &&
        other.hasScrollableContent == hasScrollableContent;
  }

  @override
  int get hashCode => Object.hash(
    workbenchSize,
    listViewportRect,
    lastTaskRect,
    addButtonRect,
    startButtonRect,
    hasScrollableContent,
  );
}

enum TaskWorkspaceGuideCapacity { hidden, startAllOnly, both }

class GuideListMetrics {
  const GuideListMetrics({required this.hasScrollableContent});

  final bool hasScrollableContent;

  @override
  bool operator ==(Object other) {
    return other is GuideListMetrics &&
        other.hasScrollableContent == hasScrollableContent;
  }

  @override
  int get hashCode => hasScrollableContent.hashCode;
}
