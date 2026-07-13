import 'package:flutter/material.dart';
import 'package:framelean/features/workbench/guide/arrow/doodle_arrow.dart';
import 'package:framelean/features/workbench/guide/content/guide_content_group.dart';
import 'package:framelean/features/workbench/workbench_icons.dart';

class ImportIconGroup extends GuideContentGroup {
  const ImportIconGroup({super.key, required super.geometry});

  @override
  String get id => 'import-icon';

  @override
  Widget build(BuildContext context) {
    final viewport = geometry.listViewportRect;
    final center = Offset(
      viewport.center.dx,
      viewport.top + viewport.height * 0.38,
    );
    final color = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.36);
    return Positioned(
      key: const ValueKey('empty-queue-guide-icon'),
      left: center.dx - 34,
      top: center.dy - 46,
      width: 68,
      height: 68,
      child: Icon(WorkbenchIcons.fileUpload, size: 54, color: color),
    );
  }
}

class ImportTextGroup extends GuideContentGroup {
  const ImportTextGroup({super.key, required super.geometry});

  @override
  String get id => 'import-text';

  @override
  Widget build(BuildContext context) {
    final viewport = geometry.listViewportRect;
    final center = Offset(
      viewport.center.dx,
      viewport.top + viewport.height * 0.38,
    );
    return Positioned(
      key: const ValueKey('empty-queue-guide-text'),
      left: center.dx - 170,
      top: center.dy + 31,
      width: 340,
      child: const GuideText(
        text: '拖拽或双击背景板来添加任务',
        textAlign: TextAlign.center,
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
    final start = Offset(
      (target.dx + 220)
          .clamp(viewport.left + 96, viewport.right - 72)
          .toDouble(),
      (target.dy - 170)
          .clamp(viewport.top + 96, viewport.bottom - 72)
          .toDouble(),
    );
    final arrowClipRect = Rect.fromLTRB(
      viewport.left,
      viewport.top,
      viewport.right,
      viewport.bottom - 8,
    );
    final color = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.38);
    return Positioned.fill(
      child: DoodleArrow(
        key: const ValueKey('add-button-guide-arrow'),
        startPoint: start,
        targetPoint: target,
        color: color,
        seed: 4207,
        maxLength: 270,
        curveBias: const Offset(20, -14),
        clipRect: arrowClipRect,
      ),
    );
  }
}

class ImportGuideGroup extends CompositeGuideGroup {
  ImportGuideGroup({super.key, required super.geometry})
    : super(
        groupId: 'import',
        children: [
          ImportIconGroup(geometry: geometry),
          ImportTextGroup(geometry: geometry),
        ],
      );
}
