import 'package:flutter/material.dart';
import 'package:framelean/features/workbench/guide/arrow/doodle_arrow.dart';
import 'package:framelean/features/workbench/guide/content/guide_content_group.dart';

class StartAllGuideGroup extends GuideContentGroup {
  const StartAllGuideGroup({super.key, required super.geometry});

  @override
  String get id => 'start-all';

  @override
  Widget build(BuildContext context) {
    final buttonRect = geometry.startButtonRect;
    if (buttonRect.isEmpty) {
      return const SizedBox.shrink();
    }
    const textWidth = 160.0;
    final textLeft = (buttonRect.center.dx + 104)
        .clamp(32.0, geometry.workbenchSize.width - textWidth - 32)
        .toDouble();
    final textTop = (buttonRect.top - 76)
        .clamp(
          geometry.listViewportRect.top + 16,
          geometry.workbenchSize.height,
        )
        .toDouble();
    final arrowStart = Offset(textLeft - 18, textTop + 12);
    final arrowTarget = Offset(buttonRect.center.dx, buttonRect.top - 22);
    // 裁剪底部比按钮顶部高 10 px，整条线不会进入开始按钮。
    final arrowClipRect = Rect.fromLTRB(
      geometry.listViewportRect.left,
      geometry.listViewportRect.top,
      geometry.listViewportRect.right,
      buttonRect.top - 10,
    );
    final color = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.38);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: DoodleArrow(
            key: const ValueKey('start-all-guide-arrow'),
            startPoint: arrowStart,
            targetPoint: arrowTarget,
            color: color,
            seed: 2803,
            maxLength: 180,
            curveBias: const Offset(-10, -18),
            clipRect: arrowClipRect,
          ),
        ),
        Positioned(
          key: const ValueKey('start-all-guide-text'),
          left: textLeft,
          top: textTop,
          width: textWidth,
          child: const GuideText(text: '点击这里全部开始'),
        ),
      ],
    );
  }
}
