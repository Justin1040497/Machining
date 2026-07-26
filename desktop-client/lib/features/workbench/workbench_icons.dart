import 'package:flutter/material.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_models.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task/task_context_menu.dart';

// ---------------------------------------------------------------------------
// MediaKind → 占位图标
// ---------------------------------------------------------------------------

extension WorkbenchMediaKindIcon on MediaKind {
  IconData get placeholderIcon {
    return switch (this) {
      MediaKind.video => Icons.movie_creation_outlined,
      MediaKind.image => Icons.image_outlined,
      MediaKind.audio => Icons.audiotrack_rounded,
    };
  }
}

// ---------------------------------------------------------------------------
// TaskStatus → 主操作图标
// ---------------------------------------------------------------------------

extension WorkbenchTaskStatusIcon on TaskStatus {
  /// 返回该状态下主操作按钮应使用的图标，不区分是否有 analysisResult。
  IconData get actionIcon {
    return switch (this) {
      TaskStatus.ready => Icons.play_circle_fill_rounded,
      TaskStatus.awaitAnalysis ||
      TaskStatus.analysisQueued ||
      TaskStatus.analyzing => Icons.hourglass_top_rounded,
      TaskStatus.executionQueued => Icons.schedule_rounded,
      TaskStatus.running => Icons.pause_rounded,
      TaskStatus.preempting ||
      TaskStatus.preempted ||
      TaskStatus.resuming => Icons.swap_vertical_circle_outlined,
      TaskStatus.paused => Icons.play_arrow_rounded,
      TaskStatus.completed => Icons.replay_rounded,
      TaskStatus.analysisFailed ||
      TaskStatus.executionFailed ||
      TaskStatus.cancelled => Icons.refresh_rounded,
      TaskStatus.missingSource => Icons.link_rounded,
    };
  }

  /// 返回该状态下主操作按钮的 tooltip 文案。
  String get actionTooltip {
    return switch (this) {
      TaskStatus.awaitAnalysis => '等待分析',
      TaskStatus.analysisQueued => '分析排队中',
      TaskStatus.analyzing => '正在分析',
      TaskStatus.ready => '开始压缩',
      TaskStatus.analysisFailed => '重试分析',
      TaskStatus.executionQueued => '执行排队中',
      TaskStatus.running => '暂停任务',
      TaskStatus.preempting => '正在抢占',
      TaskStatus.preempted => '等待自动恢复',
      TaskStatus.resuming => '正在恢复',
      TaskStatus.paused => '继续任务',
      TaskStatus.completed => '重来',
      TaskStatus.executionFailed || TaskStatus.cancelled => '重试任务',
      TaskStatus.missingSource => '重新链接源文件',
    };
  }
}

// ---------------------------------------------------------------------------
// TaskContextMenuAction → 图标
// ---------------------------------------------------------------------------

extension WorkbenchTaskContextMenuActionIcon on TaskContextMenuAction {
  IconData get icon {
    return switch (this) {
      TaskContextMenuAction.relinkSource => Icons.link_rounded,
      TaskContextMenuAction.revealInFileManager => Icons.folder_open_rounded,
      TaskContextMenuAction.rename => Icons.drive_file_rename_outline_rounded,
      TaskContextMenuAction.moveToFolder => Icons.create_new_folder_rounded,
      TaskContextMenuAction.showLog => Icons.description_outlined,
      TaskContextMenuAction.delete => Icons.delete_outline_rounded,
    };
  }

  /// 该菜单项的标签文案。
  String get label {
    return switch (this) {
      TaskContextMenuAction.relinkSource => '重新链接源文件',
      TaskContextMenuAction.revealInFileManager => '打开文件所在位置',
      TaskContextMenuAction.rename => '任务重命名',
      TaskContextMenuAction.moveToFolder => '添加到任务夹',
      TaskContextMenuAction.showLog => '查看日志',
      TaskContextMenuAction.delete => '删除任务',
    };
  }
}

// ---------------------------------------------------------------------------
// TaskFolderContextMenuAction → 图标
// ---------------------------------------------------------------------------

extension WorkbenchTaskFolderContextMenuActionIcon
    on TaskFolderContextMenuAction {
  IconData get icon {
    return switch (this) {
      TaskFolderContextMenuAction.rename =>
        Icons.drive_file_rename_outline_rounded,
      TaskFolderContextMenuAction.openContents => Icons.folder_open_rounded,
      TaskFolderContextMenuAction.showLog => Icons.description_outlined,
      TaskFolderContextMenuAction.delete => Icons.delete_outline_rounded,
    };
  }

  String get label {
    return switch (this) {
      TaskFolderContextMenuAction.rename => '任务夹重命名',
      TaskFolderContextMenuAction.openContents => '查看夹内任务',
      TaskFolderContextMenuAction.showLog => '查看夹内任务日志',
      TaskFolderContextMenuAction.delete => '删除任务夹',
    };
  }
}

// ---------------------------------------------------------------------------
// 工作台散落图标常量
// ---------------------------------------------------------------------------

/// 工作台中不直接绑定到某个枚举值的独立图标常量。
///
/// 所有工作台组件的图标引用都应从此处获取，避免散落 `Icons.xxx` 字面量。
class WorkbenchIcons {
  WorkbenchIcons._();

  // -- 任务操作 ----------------------------------------------------------------

  static const IconData play = Icons.play_circle_fill_rounded;
  static const IconData pause = Icons.pause_rounded;
  static const IconData resume = Icons.play_arrow_rounded;
  static const IconData replay = Icons.replay_rounded;
  static const IconData retry = Icons.refresh_rounded;
  static const IconData relink = Icons.link_rounded;

  // -- 文件 / 文件夹 -----------------------------------------------------------

  static const IconData folder = Icons.folder_rounded;
  static const IconData folderOpen = Icons.folder_open_rounded;
  static const IconData newFolder = Icons.create_new_folder_rounded;
  static const IconData folderCopy = Icons.folder_copy_rounded;
  static const IconData fileOpen = Icons.file_open_outlined;
  static const IconData fileUpload = Icons.file_upload_outlined;

  // -- 通用操作 ----------------------------------------------------------------

  static const IconData rename = Icons.drive_file_rename_outline_rounded;
  static const IconData log = Icons.description_outlined;
  static const IconData delete = Icons.delete_outline_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData remove = Icons.remove_circle_outline_rounded;
  static const IconData add = Icons.add_rounded;
  static const IconData selectAll = Icons.select_all_rounded;
  static const IconData settings = Icons.settings;
  static const IconData openInNew = Icons.open_in_new_rounded;

  // -- 导航 / 拖拽 -------------------------------------------------------------

  static const IconData dragIndicator = Icons.drag_indicator_rounded;
  static const IconData chevronRight = Icons.chevron_right_rounded;
  static const IconData back = Icons.keyboard_arrow_left_rounded;

  // -- 顶栏 --------------------------------------------------------------------

  static const IconData lightMode = Icons.light_mode_outlined;
  static const IconData darkMode = Icons.dark_mode_outlined;
  static const IconData downloadDone = Icons.download_done_outlined;
  static const IconData fileDownload = Icons.file_download_outlined;
  static const IconData notifications = Icons.notifications_none_rounded;
}
