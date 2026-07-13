import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/features/workbench/guide/models/guide_geometry.dart';
import 'package:framelean/features/workbench/guide/models/guide_state.dart';
import 'package:framelean/features/workbench/guide/scheduler/guide_scheduler.dart';

void main() {
  test('initial empty queue fades in', () {
    final scheduler = GuideScheduler();
    final decision = scheduler.update(
      GuideSchedulerInput(taskCount: 0, geometry: geometry()),
    );

    expect(decision.scene, GuideScene.emptyQueue);
    expect(decision.transition, GuideTransitionKind.fadeIn);
  });

  test('task count changes keep the scene and only move positions', () {
    final scheduler = GuideScheduler();
    scheduler.update(GuideSchedulerInput(taskCount: 1, geometry: geometry()));
    final decision = scheduler.update(
      GuideSchedulerInput(
        taskCount: 2,
        geometry: geometry(lastTaskRect: const Rect.fromLTWH(24, 90, 700, 72)),
      ),
    );

    expect(decision.scene, GuideScene.taskWorkspace);
    expect(decision.transition, GuideTransitionKind.positionOnly);
  });

  test('empty and task workspace changes use a scene swap', () {
    final scheduler = GuideScheduler();
    scheduler.update(GuideSchedulerInput(taskCount: 2, geometry: geometry()));

    final emptyDecision = scheduler.update(
      GuideSchedulerInput(taskCount: 0, geometry: geometry()),
    );
    expect(emptyDecision.scene, GuideScene.emptyQueue);
    expect(emptyDecision.transition, GuideTransitionKind.sceneSwap);

    final taskDecision = scheduler.update(
      GuideSchedulerInput(taskCount: 1, geometry: geometry()),
    );
    expect(taskDecision.scene, GuideScene.taskWorkspace);
    expect(taskDecision.transition, GuideTransitionKind.sceneSwap);
  });

  test('scrollable or crowded lists hide task workspace guides', () {
    final scrollScheduler = GuideScheduler();
    final scrollDecision = scrollScheduler.update(
      GuideSchedulerInput(
        taskCount: 4,
        geometry: geometry(hasScrollableContent: true),
      ),
    );
    expect(scrollDecision.scene, GuideScene.hidden);

    final crowdedScheduler = GuideScheduler();
    final crowdedDecision = crowdedScheduler.update(
      GuideSchedulerInput(
        taskCount: 2,
        geometry: geometry(lastTaskRect: const Rect.fromLTWH(24, 450, 700, 90)),
      ),
    );
    expect(crowdedDecision.scene, GuideScene.hidden);
  });

  test('loading state stays hidden even when anchors exist', () {
    final decision = GuideScheduler().update(
      GuideSchedulerInput(taskCount: null, geometry: geometry()),
    );
    expect(decision.scene, GuideScene.hidden);
  });
}

GuideGeometry geometry({
  Rect lastTaskRect = const Rect.fromLTWH(24, 80, 700, 72),
  bool hasScrollableContent = false,
}) {
  return GuideGeometry(
    workbenchSize: const Size(900, 700),
    listViewportRect: const Rect.fromLTWH(0, 0, 900, 638),
    lastTaskRect: lastTaskRect,
    addButtonRect: const Rect.fromLTWH(20, 650, 36, 36),
    startButtonRect: const Rect.fromLTWH(416, 610, 68, 68),
    hasScrollableContent: hasScrollableContent,
  );
}
