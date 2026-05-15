import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:machining/domain/entities/media_task.dart';

class WorkbenchBottomBar extends StatelessWidget {
  const WorkbenchBottomBar({
    super.key,
    required this.taskList,
    required this.hasRunningTask,
    required this.queueActionInFlight,
    required this.onAddTask,
    // ignore: unused_element
    required this.onOpenSettings,
    required this.onClearTasks,
    required this.onPrimaryQueuePressed,
  });

  final AsyncValue<List<MediaTask>> taskList;
  final bool hasRunningTask;
  final bool queueActionInFlight;
  final VoidCallback onAddTask;
  final VoidCallback onOpenSettings;
  final VoidCallback onClearTasks;
  final VoidCallback onPrimaryQueuePressed;

  @override
  Widget build(BuildContext context) {
    final hasTasks = taskList.hasValue && taskList.requireValue.isNotEmpty;

    return SizedBox(
      height: 62,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox.expand(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  _DockIconButton(
                    tooltip: '添加任务',
                    icon: Icons.add_rounded,
                    onPressed: onAddTask,
                    size: 26,
                  ),
                  // const SizedBox(width: 12),
                  // _DockIconButton(
                  //   tooltip: '设置',
                  //   icon: Icons.settings,
                  //   onPressed: onOpenSettings,
                  // ),
                  const Spacer(),
                  _DockIconButton(
                    tooltip: '清空列表',
                    icon: Icons.delete_outline_rounded,
                    color: const Color(0xFFFF5B61),
                    onPressed: hasTasks ? onClearTasks : null,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 62 / 2 - 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PrimaryQueueButton(
                  hasTasks: hasTasks,
                  hasRunningTask: hasRunningTask,
                  queueActionInFlight: queueActionInFlight,
                  onPressed: onPrimaryQueuePressed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DockIconButton extends StatelessWidget {
  const _DockIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.size = 22,
    this.color = Colors.black,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: size, color: color),
      ),
    );
  }
}

class _PrimaryQueueButton extends StatelessWidget {
  const _PrimaryQueueButton({
    required this.hasTasks,
    required this.hasRunningTask,
    required this.queueActionInFlight,
    required this.onPressed,
  });

  final bool hasTasks;
  final bool hasRunningTask;
  final bool queueActionInFlight;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: hasRunningTask ? '暂停所有任务' : '开始执行',
      child: SizedBox(
        width: 68,
        height: 68,
        child: FilledButton(
          onPressed: hasTasks && !queueActionInFlight ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6290FF),
            disabledBackgroundColor: const Color(0xFFB9CBFF),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white,
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
            elevation: 0,
          ),
          child: Icon(
            hasRunningTask ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 34,
          ),
        ),
      ),
    );
  }
}
