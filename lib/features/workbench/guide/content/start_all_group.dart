import 'package:flutter/material.dart';
import 'package:framelean/features/workbench/guide/arrow/doodle_arrow.dart';
import 'package:framelean/features/workbench/guide/content/guide_content_group.dart';
import 'package:framelean/features/workbench/guide/models/task_workspace_guide_layout.dart';

class StartAllGuideGroup extends GuideContentGroup {
  const StartAllGuideGroup({
    super.key,
    required super.geometry,
    required this.placement,
  });

  final StartAllGuidePlacement placement;

  @override
  String get id => 'start-all';

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.42);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: DoodleArrow(
            key: const ValueKey('start-all-guide-arrow'),
            startPoint: placement.arrowStart,
            targetPoint: placement.arrowTarget,
            color: color,
            seed: StartAllGuidePlacement.arrowSeed,
            maxLength: StartAllGuidePlacement.maxArrowLength,
            curveBias: StartAllGuidePlacement.curveBias,
            targetDirection: StartAllGuidePlacement.targetDirection,
            clipRect: placement.lane,
          ),
        ),
        Positioned(
          key: const ValueKey('start-all-guide-text'),
          left: placement.textRect.left,
          top: placement.textRect.top,
          width: placement.textRect.width,
          child: const GuideText(text: '点击这里全部开始'),
        ),
      ],
    );
  }
}
