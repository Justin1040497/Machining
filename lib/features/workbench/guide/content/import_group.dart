import 'package:flutter/material.dart';
import 'package:framelean/features/workbench/guide/arrow/doodle_arrow.dart';
import 'package:framelean/features/workbench/guide/content/guide_content_group.dart';
import 'package:framelean/features/workbench/guide/models/guide_geometry.dart';
import 'package:framelean/features/workbench/workbench_icons.dart';

class ImportGuideGroup extends GuideContentGroup {
  const ImportGuideGroup({super.key, required super.geometry});

  @override
  String get id => 'import';

  @override
  Widget build(BuildContext context) {
    final viewport = geometry.listViewportRect;
    final color = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.36);
    return Positioned.fromRect(
      rect: viewport,
      child: Center(
        child: Column(
          key: const ValueKey('empty-queue-guide-content'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              WorkbenchIcons.fileUpload,
              key: const ValueKey('empty-queue-guide-icon'),
              size: 54,
              color: color,
            ),
            const SizedBox(height: 18),
            const GuideText(
              key: ValueKey('empty-queue-guide-text'),
              text: '可以直接把文件拖进来\n或者双击背景板\n又或者点击左小角的"+"号来添加媒体任务',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class AddButtonArrowGroup extends GuideContentGroup {
  const AddButtonArrowGroup({super.key, required super.geometry});

  @override
  String get id => 'add-button-arrow';

  @override
  Widget build(BuildContext context) {
    final viewport = geometry.listViewportRect;
    // 终点停在列表视口底部上方 20 px（即 BottomBar 顶部上方），避免被底部栏盖住。
    final target = Offset(
      geometry.addButtonRect.center.dx,
      viewport.bottom - 20,
    );
    // 起点位于目标右上方，形成左下区域内的短涂鸦箭头，不再贯穿大半个页面。
    final start = _addButtonArrowStart(geometry);
    final arrowClipRect = Rect.fromLTRB(
      viewport.left,
      viewport.top,
      viewport.right,
      viewport.bottom - 8,
    );
    final color = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.42);
    return Positioned.fill(
      child: DoodleArrow(
        key: const ValueKey('add-button-guide-arrow'),
        startPoint: start,
        targetPoint: target,
        color: color,
        seed: 4207,
        maxLength: 180,
        curveBias: const Offset(0, -72),
        targetDirection: const Offset(0, 1),
        clipRect: arrowClipRect,
      ),
    );
  }
}

Offset _addButtonArrowStart(GuideGeometry geometry) {
  final viewport = geometry.listViewportRect;
  final target = Offset(geometry.addButtonRect.center.dx, viewport.bottom - 20);
  return Offset(
    (target.dx + 135).clamp(viewport.left + 96, viewport.right - 72).toDouble(),
    (target.dy - 72).clamp(viewport.top + 96, viewport.bottom - 72).toDouble(),
  );
}
