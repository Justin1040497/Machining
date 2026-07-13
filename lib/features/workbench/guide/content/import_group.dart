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
    final start = Offset(
      viewport.center.dx - 118,
      viewport.top + viewport.height * 0.38 + 64,
    );
    final target = geometry.addButtonRect.topCenter + const Offset(0, 3);
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
