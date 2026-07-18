import 'package:framelean/features/workbench/guide/models/guide_geometry.dart';

enum GuideScene { hidden, emptyQueue, taskWorkspace, transitioning }

enum GuideTransitionKind { none, fadeIn, fadeOut, sceneSwap, positionOnly }

class GuideSchedulerInput {
  const GuideSchedulerInput({required this.taskCount, required this.geometry});

  final int? taskCount;
  final GuideGeometry? geometry;
}

class GuideScheduleDecision {
  const GuideScheduleDecision({required this.scene, required this.transition});

  final GuideScene scene;
  final GuideTransitionKind transition;
}
