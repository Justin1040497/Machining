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

  static const double minimumGuideHeight = 132;

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

  bool get hasTaskAnchors => lastTaskRect != null && !startButtonRect.isEmpty;

  bool get canShowTaskWorkspaceGuide {
    return hasTaskAnchors &&
        !hasScrollableContent &&
        taskGuideHeight >= minimumGuideHeight;
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
