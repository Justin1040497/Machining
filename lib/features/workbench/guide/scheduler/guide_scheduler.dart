import 'package:framelean/features/workbench/guide/models/guide_state.dart';

class GuideScheduler {
  GuideScene _scene = GuideScene.hidden;

  GuideScene get scene => _scene;

  GuideScheduleDecision update(GuideSchedulerInput input) {
    final nextScene = _resolveScene(input);
    final previousScene = _scene;
    _scene = nextScene;

    if (previousScene == nextScene) {
      return GuideScheduleDecision(
        scene: nextScene,
        transition: nextScene == GuideScene.taskWorkspace
            ? GuideTransitionKind.positionOnly
            : GuideTransitionKind.none,
      );
    }
    if (previousScene == GuideScene.hidden) {
      return GuideScheduleDecision(
        scene: nextScene,
        transition: nextScene == GuideScene.hidden
            ? GuideTransitionKind.none
            : GuideTransitionKind.fadeIn,
      );
    }
    if (nextScene == GuideScene.hidden) {
      return const GuideScheduleDecision(
        scene: GuideScene.hidden,
        transition: GuideTransitionKind.fadeOut,
      );
    }
    return GuideScheduleDecision(
      scene: nextScene,
      transition: GuideTransitionKind.sceneSwap,
    );
  }

  GuideScene _resolveScene(GuideSchedulerInput input) {
    final geometry = input.geometry;
    if (geometry == null || input.taskCount == null) {
      return GuideScene.hidden;
    }
    if (input.taskCount == 0) {
      return geometry.canShowEmptyQueueGuide
          ? GuideScene.emptyQueue
          : GuideScene.hidden;
    }
    return geometry.canShowTaskWorkspaceGuide
        ? GuideScene.taskWorkspace
        : GuideScene.hidden;
  }
}
