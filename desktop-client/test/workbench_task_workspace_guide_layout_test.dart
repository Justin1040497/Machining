import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/features/workbench/guide/models/guide_geometry.dart';
import 'package:framelean/features/workbench/guide/models/task_workspace_guide_layout.dart';

void main() {
  test('360 px or more creates two separated safe lanes', () {
    final layout = TaskWorkspaceGuideLayout.resolve(
      geometryWithSafeHeight(360),
    );

    expect(layout.capacity, TaskWorkspaceGuideCapacity.both);
    final task = layout.taskOperation!;
    final start = layout.startAll!;
    expect(start.lane.top - task.lane.bottom, 28);
    expect(task.lane.overlaps(start.lane), isFalse);
    expect(task.visualRect.overlaps(start.visualRect), isFalse);
    expect(_contains(task.lane, task.visualRect), isTrue);
    expect(_contains(start.lane, start.visualRect), isTrue);
  });

  test('single-task 1370 px workspace keeps both guide groups visible', () {
    final layout = TaskWorkspaceGuideLayout.resolve(
      const GuideGeometry(
        workbenchSize: Size(1370, 1370),
        listViewportRect: Rect.fromLTWH(0, 103, 1370, 1142),
        lastTaskRect: Rect.fromLTWH(55, 165, 1260, 170),
        addButtonRect: Rect.fromLTWH(62, 1288, 36, 36),
        startButtonRect: Rect.fromLTWH(617, 1197, 136, 136),
        hasScrollableContent: false,
      ),
    );

    expect(layout.capacity, TaskWorkspaceGuideCapacity.both);
    expect(layout.taskOperation, isNotNull);
    expect(layout.startAll, isNotNull);
  });

  test('180 to 359 px keeps only the start-all guide', () {
    final layout = TaskWorkspaceGuideLayout.resolve(
      geometryWithSafeHeight(180),
    );

    expect(layout.capacity, TaskWorkspaceGuideCapacity.startAllOnly);
    expect(layout.taskOperation, isNull);
    expect(layout.startAll, isNotNull);
    expect(
      layout.startAll!.lane,
      geometryWithSafeHeight(180).taskWorkspaceGuideRect,
    );
  });

  test('less than 180 px hides task workspace guides', () {
    final layout = TaskWorkspaceGuideLayout.resolve(
      geometryWithSafeHeight(179),
    );

    expect(layout.capacity, TaskWorkspaceGuideCapacity.hidden);
    expect(layout.taskOperation, isNull);
    expect(layout.startAll, isNull);
  });

  test('scrollable task lists remain hidden regardless of free height', () {
    final layout = TaskWorkspaceGuideLayout.resolve(
      geometryWithSafeHeight(400, hasScrollableContent: true),
    );

    expect(layout.capacity, TaskWorkspaceGuideCapacity.hidden);
  });
}

GuideGeometry geometryWithSafeHeight(
  double safeHeight, {
  bool hasScrollableContent = false,
}) {
  const safeBottom = 600.0;
  const taskHeight = 72.0;
  final taskBottom = safeBottom - 16 - safeHeight;
  return GuideGeometry(
    workbenchSize: const Size(900, 700),
    listViewportRect: const Rect.fromLTWH(0, 0, 900, 638),
    lastTaskRect: Rect.fromLTWH(24, taskBottom - taskHeight, 700, taskHeight),
    addButtonRect: const Rect.fromLTWH(20, 650, 36, 36),
    startButtonRect: const Rect.fromLTWH(416, 610, 68, 68),
    hasScrollableContent: hasScrollableContent,
  );
}

bool _contains(Rect outer, Rect inner) {
  const tolerance = 0.5;
  return inner.left >= outer.left - tolerance &&
      inner.top >= outer.top - tolerance &&
      inner.right <= outer.right + tolerance &&
      inner.bottom <= outer.bottom + tolerance;
}
