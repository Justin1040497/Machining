import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:framelean/app/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_models.dart';
import 'package:framelean/features/workbench/workbench_icons.dart';

class TaskContextMenuResult {
  const TaskContextMenuResult(this.action, {this.folderId});

  const TaskContextMenuResult.moveToFolder(this.folderId)
    : action = TaskContextMenuAction.moveToFolder,
      super();

  final TaskContextMenuAction action;
  final String? folderId;
}

enum TaskFolderContextMenuAction { rename, openContents, showLog, delete }

Future<TaskContextMenuResult?> showWorkbenchTaskContextMenu({
  required BuildContext context,
  required MediaTask task,
  required Offset globalPosition,
  required List<TaskFolder> candidateFolders,
}) {
  final eligibleFolders = task.folderId == null
      ? candidateFolders
            .where((folder) => folder.mediaKind == task.mediaKind)
            .toList()
      : const <TaskFolder>[];
  return showGeneralDialog<TaskContextMenuResult>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭菜单',
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (context, _, _) {
      return _TaskContextMenuOverlay(
        task: task,
        position: globalPosition,
        eligibleFolders: eligibleFolders,
      );
    },
  );
}

Future<TaskFolderContextMenuAction?> showWorkbenchTaskFolderContextMenu({
  required BuildContext context,
  required TaskFolder folder,
  required bool hasLoggableTask,
  required Offset globalPosition,
}) {
  return showGeneralDialog<TaskFolderContextMenuAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭菜单',
    barrierColor: Colors.transparent,
    transitionDuration: Duration.zero,
    pageBuilder: (context, _, _) {
      return _FolderContextMenuOverlay(
        position: globalPosition,
        folder: folder,
        hasLoggableTask: hasLoggableTask,
      );
    },
  );
}

class _TaskContextMenuOverlay extends StatefulWidget {
  const _TaskContextMenuOverlay({
    required this.task,
    required this.position,
    required this.eligibleFolders,
  });

  final MediaTask task;
  final Offset position;
  final List<TaskFolder> eligibleFolders;

  @override
  State<_TaskContextMenuOverlay> createState() =>
      _TaskContextMenuOverlayState();
}

class _TaskContextMenuOverlayState extends State<_TaskContextMenuOverlay> {
  static const _menuWidth = 218.0;
  static const _submenuWidth = 220.0;
  static const _itemHeight = 38.0;
  static const _menuPadding = 6.0;

  bool folderSubmenuOpen = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final mainHeight = _taskMenuItemCount * _itemHeight + _menuPadding * 2;
    final mainLeft = widget.position.dx
        .clamp(8.0, math.max(8.0, size.width - _menuWidth - 8))
        .toDouble();
    final mainTop = widget.position.dy
        .clamp(8.0, math.max(8.0, size.height - mainHeight - 8))
        .toDouble();
    final addToFolderTop =
        mainTop + _menuPadding + _addToFolderIndex * _itemHeight;
    final submenuLeft =
        (mainLeft + _menuWidth + _submenuWidth + 6 <= size.width - 8
                ? mainLeft + _menuWidth + 6
                : math.max(8.0, mainLeft - _submenuWidth - 6))
            .toDouble();
    final submenuHeight = (widget.eligibleFolders.length * _itemHeight)
        .clamp(_itemHeight, 240)
        .toDouble();
    final submenuTop = addToFolderTop
        .clamp(
          8.0,
          math.max(8.0, size.height - submenuHeight - _menuPadding * 2 - 8),
        )
        .toDouble();

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            left: mainLeft,
            top: mainTop,
            width: _menuWidth,
            child: _ContextMenuSurface(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.task.status == TaskStatus.missingSource)
                    _ContextMenuItem(
                      icon: TaskContextMenuAction.relinkSource.icon,
                      label: TaskContextMenuAction.relinkSource.label,
                      onTap: () => Navigator.of(context).pop(
                        const TaskContextMenuResult(
                          TaskContextMenuAction.relinkSource,
                        ),
                      ),
                    ),
                  _ContextMenuItem(
                    icon: TaskContextMenuAction.revealInFileManager.icon,
                    label: TaskContextMenuAction.revealInFileManager.label,
                    onTap: () => Navigator.of(context).pop(
                      const TaskContextMenuResult(
                        TaskContextMenuAction.revealInFileManager,
                      ),
                    ),
                  ),
                  _ContextMenuItem(
                    icon: TaskContextMenuAction.rename.icon,
                    label: TaskContextMenuAction.rename.label,
                    onTap: () => Navigator.of(context).pop(
                      const TaskContextMenuResult(TaskContextMenuAction.rename),
                    ),
                  ),
                  MouseRegion(
                    onEnter: (_) {
                      if (widget.eligibleFolders.isNotEmpty) {
                        setState(() => folderSubmenuOpen = true);
                      }
                    },
                    child: _ContextMenuItem(
                      icon: TaskContextMenuAction.moveToFolder.icon,
                      trailing: WorkbenchIcons.chevronRight,
                      label: TaskContextMenuAction.moveToFolder.label,
                      enabled: widget.eligibleFolders.isNotEmpty,
                      onTap: widget.eligibleFolders.isEmpty
                          ? null
                          : () => setState(
                              () => folderSubmenuOpen = !folderSubmenuOpen,
                            ),
                    ),
                  ),
                  _ContextMenuItem(
                    icon: TaskContextMenuAction.showLog.icon,
                    label: TaskContextMenuAction.showLog.label,
                    onTap: () => Navigator.of(context).pop(
                      const TaskContextMenuResult(
                        TaskContextMenuAction.showLog,
                      ),
                    ),
                  ),
                  _ContextMenuItem(
                    icon: TaskContextMenuAction.delete.icon,
                    label: TaskContextMenuAction.delete.label,
                    danger: true,
                    onTap: () => Navigator.of(context).pop(
                      const TaskContextMenuResult(TaskContextMenuAction.delete),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (folderSubmenuOpen && widget.eligibleFolders.isNotEmpty)
            Positioned(
              left: submenuLeft,
              top: submenuTop,
              width: _submenuWidth,
              child: MouseRegion(
                onEnter: (_) => setState(() => folderSubmenuOpen = true),
                child: _ContextMenuSurface(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: [
                        for (final folder in widget.eligibleFolders)
                          _ContextMenuItem(
                            icon: WorkbenchIcons.folder,
                            label: folder.name,
                            onTap: () => Navigator.of(context).pop(
                              TaskContextMenuResult.moveToFolder(folder.id),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  int get _taskMenuItemCount {
    return widget.task.status == TaskStatus.missingSource ? 6 : 5;
  }

  int get _addToFolderIndex {
    return widget.task.status == TaskStatus.missingSource ? 3 : 2;
  }
}

class _FolderContextMenuOverlay extends StatelessWidget {
  const _FolderContextMenuOverlay({
    required this.position,
    required this.folder,
    required this.hasLoggableTask,
  });

  static const _menuWidth = 218.0;
  static const _itemHeight = 38.0;
  static const _menuPadding = 6.0;

  final Offset position;
  final TaskFolder folder;
  final bool hasLoggableTask;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final menuHeight = 4 * _itemHeight + _menuPadding * 2;
    final left = position.dx
        .clamp(8.0, math.max(8.0, size.width - _menuWidth - 8))
        .toDouble();
    final top = position.dy
        .clamp(8.0, math.max(8.0, size.height - menuHeight - 8))
        .toDouble();

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: _menuWidth,
            child: _ContextMenuSurface(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ContextMenuItem(
                    icon: TaskFolderContextMenuAction.rename.icon,
                    label: TaskFolderContextMenuAction.rename.label,
                    onTap: () => Navigator.of(
                      context,
                    ).pop(TaskFolderContextMenuAction.rename),
                  ),
                  _ContextMenuItem(
                    icon: TaskFolderContextMenuAction.openContents.icon,
                    label: TaskFolderContextMenuAction.openContents.label,
                    onTap: () => Navigator.of(
                      context,
                    ).pop(TaskFolderContextMenuAction.openContents),
                  ),
                  _ContextMenuItem(
                    icon: TaskFolderContextMenuAction.showLog.icon,
                    label: TaskFolderContextMenuAction.showLog.label,
                    enabled: hasLoggableTask,
                    onTap: hasLoggableTask
                        ? () => Navigator.of(
                            context,
                          ).pop(TaskFolderContextMenuAction.showLog)
                        : null,
                  ),
                  _ContextMenuItem(
                    icon: TaskFolderContextMenuAction.delete.icon,
                    label: TaskFolderContextMenuAction.delete.label,
                    danger: true,
                    onTap: () => Navigator.of(
                      context,
                    ).pop(TaskFolderContextMenuAction.delete),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextMenuSurface extends StatelessWidget {
  const _ContextMenuSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Material(
      color: colors.surface,
      elevation: 3,
      shadowColor: colors.shadow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: child,
      ),
    );
  }
}

class _ContextMenuItem extends StatelessWidget {
  const _ContextMenuItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.enabled = true,
    this.danger = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final bool danger;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final active = enabled && onTap != null;
    final foreground = !active
        ? colors.textTertiary
        : danger
        ? colors.statusFailed
        : colors.textPrimary;

    return SizedBox(
      height: 38,
      child: InkWell(
        onTap: active ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12.flSp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (trailing != null) Icon(trailing, size: 18, color: foreground),
            ],
          ),
        ),
      ),
    );
  }
}
