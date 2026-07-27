import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/app/constants.dart';
import 'package:framelean/app/presentation/widgets/reorderable/framelean_reorderable_list_view.dart';
import 'package:framelean/app/theme/framelean_colors.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/app_theme_mode.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/output_format.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/value_objects/audio_processing_config.dart';
import 'package:framelean/domain/value_objects/image_processing_config.dart';
import 'package:framelean/domain/value_objects/media_analysis_result.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/domain/value_objects/source_file_fingerprint.dart';
import 'package:framelean/domain/value_objects/task_failure.dart';
import 'package:framelean/domain/value_objects/video_task_config.dart';
import 'package:framelean/app/presentation/widgets/confirm_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task/task_configuration_dialog_widgets.dart';
import 'package:framelean/features/workbench/pages/workbench_page/layout/workbench_shell.dart';
import 'package:framelean/features/workbench/pages/workbench_page/layout/top_bar.dart';
import 'package:framelean/features/workbench/widgets/media_task_list/media_task_list_tile.dart';
import 'package:framelean/features/workbench/widgets/media_task_list/task_folder_content_panel.dart';
import 'package:framelean/features/workbench/widgets/media_task_list/task_folder_list_tile.dart';
import 'package:framelean/domain/entities/task_folder.dart';

void main() {
  test('opened task folder list is mutable when no folder is open', () {
    final folderTasks = resolveOpenedTaskFolderTasks(
      tasks: const [],
      openedFolder: null,
    );

    expect(folderTasks, isEmpty);
    expect(() => folderTasks.add(testTask()), returnsNormally);
  });

  test(
    'opened task folder list only includes folder children in folder order',
    () {
      final folder = TaskFolder(
        id: 'folder-1',
        name: '视频任务夹（1）',
        mediaKind: MediaKind.video,
        sortOrder: 0,
        createdAt: 1,
        updatedAt: 1,
      );
      final laterTask = testTask(
        fileName: 'later.mp4',
      ).copyWith(id: 'later', folderId: folder.id, folderSortOrder: 2);
      final earlierTask = testTask(
        fileName: 'earlier.mp4',
      ).copyWith(id: 'earlier', folderId: folder.id, folderSortOrder: 1);
      final looseTask = testTask(fileName: 'loose.mp4').copyWith(id: 'loose');

      final folderTasks = resolveOpenedTaskFolderTasks(
        tasks: [laterTask, looseTask, earlierTask],
        openedFolder: folder,
      );

      expect(folderTasks.map((task) => task.id), ['earlier', 'later']);
    },
  );

  testWidgets('folder configuration shows aggregate summary', (tester) async {
    final folder = TaskFolder.create(
      name: '视频任务夹 1',
      mediaKind: MediaKind.video,
      sortOrder: 0,
    );
    final tasks = [
      testTask(fileName: 'first.mp4').copyWith(
        sourceFileFingerprint: const SourceFileFingerprint(
          fileSize: 1024,
          lastModifiedAt: 1,
        ),
        analysisResult: MediaAnalysisResult(
          durationMs: 1000,
          containerFormat: 'mp4',
        ),
      ),
      testTask(fileName: 'second.mov').copyWith(
        sourceFileFingerprint: const SourceFileFingerprint(
          fileSize: 2048,
          lastModifiedAt: 1,
        ),
        analysisResult: MediaAnalysisResult(
          durationMs: 2000,
          containerFormat: 'mov',
        ),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkbenchTaskFolderSummary(folder: folder, tasks: tasks),
        ),
      ),
    );

    expect(find.text('任务数量: 2'), findsOneWidget);
    expect(find.textContaining('源文件总大小:'), findsOneWidget);
    expect(find.textContaining('MP4 × 1'), findsOneWidget);
    expect(find.textContaining('MOV × 1'), findsOneWidget);
    expect(find.textContaining('总时长:'), findsOneWidget);
    expect(find.textContaining('源文件大小:'), findsNothing);
  });

  testWidgets('missing source task action relinks instead of retrying', (
    tester,
  ) async {
    var relinkCount = 0;
    var retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaTaskListTile(
            task: testTask(status: TaskStatus.missingSource),
            onRelink: () {
              relinkCount += 1;
            },
            onRetry: () {
              retryCount += 1;
            },
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.link_rounded), findsOneWidget);
    expect(find.byTooltip('重新链接源文件'), findsOneWidget);

    await tester.tap(find.byTooltip('重新链接源文件'));
    await tester.pump();

    expect(relinkCount, 1);
    expect(retryCount, 0);
  });

  testWidgets('ready task starts instead of retrying', (tester) async {
    var startCount = 0;
    var retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaTaskListTile(
            task: testTask(status: TaskStatus.ready),
            onStart: () {
              startCount += 1;
            },
            onRetry: () {
              retryCount += 1;
            },
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.play_circle_fill_rounded), findsOneWidget);
    expect(find.byTooltip('开始压缩'), findsOneWidget);
    expect(find.byTooltip('重试任务'), findsNothing);

    await tester.tap(find.byTooltip('开始压缩'));
    await tester.pump();

    expect(startCount, 1);
    expect(retryCount, 0);
  });

  testWidgets('task action button does not also open the task tile', (
    tester,
  ) async {
    var startCount = 0;
    var openCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaTaskListTile(
            task: testTask(status: TaskStatus.ready),
            onTap: () {
              openCount += 1;
            },
            onStart: () {
              startCount += 1;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('开始压缩'));
    await tester.pump();

    expect(startCount, 1);
    expect(openCount, 0);
  });

  testWidgets('ready task without analysis has no primary action', (
    tester,
  ) async {
    var startCount = 0;
    var retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaTaskListTile(
            task: testTask(status: TaskStatus.ready, hasAnalysisResult: false),
            onStart: () {
              startCount += 1;
            },
            onRetry: () {
              retryCount += 1;
            },
          ),
        ),
      ),
    );

    expect(find.byTooltip('开始压缩'), findsNothing);
    expect(find.byTooltip('重试任务'), findsNothing);

    expect(startCount, 0);
    expect(retryCount, 0);
  });

  testWidgets('queued task shows the authoritative Engine queue position', (
    tester,
  ) async {
    final task = testTask(status: TaskStatus.analysisQueued);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaTaskListTile(
            task: task,
            engineProjection: EngineAnalysisProjection(
              taskId: task.id,
              clientFileId: task.id,
              engineSessionId: 'session-1',
              analysisQueuePosition: 3,
              analysisQueueRevision: 7,
              lastEventSequence: 9,
              updatedAt: DateTime.fromMillisecondsSinceEpoch(1),
            ),
          ),
        ),
      ),
    );

    expect(find.text('分析队列第 3 位'), findsOneWidget);
  });

  testWidgets('paused task continues with a different icon than start', (
    tester,
  ) async {
    var startCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaTaskListTile(
            task: testTask(status: TaskStatus.paused),
            onStart: () {
              startCount += 1;
            },
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_fill_rounded), findsNothing);
    expect(find.byTooltip('继续任务'), findsOneWidget);

    await tester.tap(find.byTooltip('继续任务'));
    await tester.pump();

    expect(startCount, 1);
  });

  testWidgets('execution-failed task retries instead of starting', (
    tester,
  ) async {
    var startCount = 0;
    var retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaTaskListTile(
            task: testTask(status: TaskStatus.executionFailed),
            onStart: () {
              startCount += 1;
            },
            onRetry: () {
              retryCount += 1;
            },
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    expect(find.byTooltip('重试任务'), findsOneWidget);
    expect(find.byTooltip('开始压缩'), findsNothing);

    await tester.tap(find.byTooltip('重试任务'));
    await tester.pump();

    expect(startCount, 0);
    expect(retryCount, 1);
  });

  testWidgets('non-retryable engine failure hides the retry action', (
    tester,
  ) async {
    final task = testTask().markFailed(
      const TaskFailure(
        stage: TaskFailureStage.processStart,
        code: TaskFailureCode.engineExecutionUnavailable,
        userMessage: '当前版本尚未接通媒体执行链。',
        technicalSummary: 'ENGINE_EXECUTION_CHAIN_NOT_READY',
        occurredAt: 1,
        retryable: false,
      ),
    );
    var retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaTaskListTile(
            task: task,
            onRetry: () {
              retryCount += 1;
            },
          ),
        ),
      ),
    );

    expect(find.byTooltip('重试任务'), findsNothing);
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    expect(retryCount, 0);
  });

  testWidgets('completed task shows restart action', (tester) async {
    var retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaTaskListTile(
            task: testTask(status: TaskStatus.completed),
            onRetry: () {
              retryCount += 1;
            },
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.replay_rounded), findsOneWidget);
    expect(find.byTooltip('重来'), findsOneWidget);
    expect(find.byTooltip('重试任务'), findsNothing);

    await tester.tap(find.byTooltip('重来'));
    await tester.pump();

    expect(retryCount, 1);
  });

  testWidgets('completed compression task shows size reduction summary', (
    tester,
  ) async {
    final task = testTask(
      status: TaskStatus.completed,
    ).copyWith(outputFileSize: 60 * 1024 * 1024);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MediaTaskListTile(task: task)),
      ),
    );

    expect(find.text('100MB - 60MB · 压缩了40%'), findsOneWidget);
  });

  testWidgets('completed conversion task shows formats without percentage', (
    tester,
  ) async {
    final task =
        testTask(
          status: TaskStatus.completed,
          config: VideoTaskConfig.initial().copyWith(
            outputFormat: OutputFormat.mov,
          ),
        ).copyWith(
          purpose: TaskPurpose.conversion,
          outputFileSize: 60 * 1024 * 1024,
        );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MediaTaskListTile(task: task)),
      ),
    );

    expect(find.text('MP4 - MOV'), findsOneWidget);
    expect(find.textContaining('压缩了'), findsNothing);
  });

  testWidgets('task list placeholder thumbnails match media kind', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MediaTaskListTile(task: testTask()),
              MediaTaskListTile(task: imageTask()),
              MediaTaskListTile(task: audioTask()),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.movie_creation_outlined), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(find.byIcon(Icons.audiotrack_rounded), findsOneWidget);
  });

  testWidgets('source summary placeholder thumbnails match media kind', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              WorkbenchSourceSummary(task: testTask(), thumbnail: null),
              WorkbenchSourceSummary(task: imageTask(), thumbnail: null),
              WorkbenchSourceSummary(task: audioTask(), thumbnail: null),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.movie_creation_outlined), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(find.byIcon(Icons.audiotrack_rounded), findsOneWidget);
  });

  testWidgets('restart unelevated dialog warns about active tasks', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConfirmDialog(
            title: '普通模式重启',
            body: '当前有任务正在处理。普通模式重启会关闭当前管理员窗口，并中断正在执行的任务。',
            confirmLabel: '重启',
          ),
        ),
      ),
    );

    expect(find.text('普通模式重启'), findsOneWidget);
    expect(find.textContaining('中断正在执行的任务'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('重启'), findsOneWidget);
  });

  testWidgets('windows shell reserves a top notice safe area', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    var notificationsTapped = false;
    var themeTapped = false;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkbenchShell(
              taskList: AsyncData([testTask()]),
              taskFolders: const AsyncData([]),
              selectedTaskIds: const {},
              selectionMode: false,
              importEnabled: true,
              importDragging: false,
              hasRunningTask: false,
              queueActionInFlight: false,
              thumbnailForTask: (_) => null,
              onImportDraggingChanged: (_) {},
              onImportDrop: (_) {},
              onReorder: (_, _) {},
              onOpenTask: (_) {},
              onStart: (_) {},
              onPause: (_) {},
              onRemove: (_) {},
              onRetry: (_) {},
              onRelink: (_) {},
              onShowLog: (_) {},
              onRevealOutput: (_) {},
              onContextMenu: (_, _) {},
              onToggleSelectionMode: () {},
              onToggleTaskSelection: (_) {},
              onSelectTasksWithRectangle: (_, {toggle = false}) {},
              onCreateFolderFromSelection: () {},
              onMoveTaskToFolder: (_, _) {},
              onOpenFolderSettings: (_) {},
              onOpenFolderContents: (_) {},
              onStartFolder: (_) {},
              onPauseFolder: (_) {},
              onRetryFolder: (_) {},
              onRelinkFolder: (_) {},
              onShowFolderLog: (_) {},
              onDeleteFolder: (_) {},
              onAddTasks: () {},
              onOpenSettings: () {},
              themeMode: AppThemeMode.light,
              onToggleThemeMode: () {
                themeTapped = true;
              },
              onOpenNotifications: () {
                notificationsTapped = true;
              },
              unreadNotificationCount: 3,
              onClearTasks: () {},
              onPrimaryQueuePressed: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('windows-notice-safe-area')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(MediaTaskListTile)).dy,
        greaterThanOrEqualTo(topBarHeight + 30),
      );
      expect(find.byTooltip('通知中心'), findsOneWidget);
      expect(
        find.byKey(const Key('notification-unread-badge')),
        findsOneWidget,
      );
      expect(find.text('3'), findsOneWidget);
      expect(find.byTooltip('切换为深色模式'), findsOneWidget);

      await tester.tap(find.byTooltip('切换为深色模式'));
      await tester.pumpAndSettle();

      expect(themeTapped, isTrue);

      await tester.tap(find.byTooltip('通知中心'));
      await tester.pumpAndSettle();

      expect(notificationsTapped, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('workbench shell shows folders and hides their child tasks', (
    tester,
  ) async {
    final settingsCalls = <String>[];
    final openCalls = <String>[];
    final deleteCalls = <String>[];
    final folder = TaskFolder(
      id: 'folder-1',
      name: '视频任务夹（1）',
      mediaKind: MediaKind.video,
      sortOrder: 0,
      createdAt: 1,
      updatedAt: 1,
    );
    final folderTask = testTask(
      fileName: 'inside.mp4',
    ).copyWith(id: 'inside', folderId: folder.id, folderSortOrder: 0);
    final looseTask = testTask(
      fileName: 'outside.mp4',
    ).copyWith(id: 'outside', sortOrder: 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkbenchShell(
            taskList: AsyncData([folderTask, looseTask]),
            taskFolders: AsyncData([folder]),
            selectedTaskIds: const {},
            selectionMode: false,
            importEnabled: true,
            importDragging: false,
            hasRunningTask: false,
            queueActionInFlight: false,
            thumbnailForTask: (_) => null,
            onImportDraggingChanged: (_) {},
            onImportDrop: (_) {},
            onReorder: (_, _) {},
            onOpenTask: (_) {},
            onStart: (_) {},
            onPause: (_) {},
            onRemove: (_) {},
            onRetry: (_) {},
            onRelink: (_) {},
            onShowLog: (_) {},
            onRevealOutput: (_) {},
            onContextMenu: (_, _) {},
            onToggleSelectionMode: () {},
            onToggleTaskSelection: (_) {},
            onSelectTasksWithRectangle: (_, {toggle = false}) {},
            onCreateFolderFromSelection: () {},
            onMoveTaskToFolder: (_, _) {},
            onOpenFolderSettings: (folder) {
              settingsCalls.add(folder.id);
            },
            onOpenFolderContents: (folder) {
              openCalls.add(folder.id);
            },
            onStartFolder: (_) {},
            onPauseFolder: (_) {},
            onRetryFolder: (_) {},
            onRelinkFolder: (_) {},
            onShowFolderLog: (_) {},
            onDeleteFolder: (folder) {
              deleteCalls.add(folder.id);
            },
            onAddTasks: () {},
            onOpenSettings: () {},
            themeMode: AppThemeMode.light,
            onToggleThemeMode: () {},
            onOpenNotifications: () {},
            onClearTasks: () {},
            onPrimaryQueuePressed: () {},
          ),
        ),
      ),
    );

    expect(find.text('视频任务夹（1）'), findsOneWidget);
    expect(find.text('outside.mp4'), findsOneWidget);
    expect(find.text('inside.mp4'), findsNothing);
    expect(find.textContaining('1 个任务'), findsOneWidget);

    await tester.tap(find.text('视频任务夹（1）'));
    await tester.pumpAndSettle();
    expect(settingsCalls, ['folder-1']);
    expect(openCalls, isEmpty);

    await tester.tap(find.byTooltip('查看夹内任务'));
    await tester.pumpAndSettle();
    expect(openCalls, ['folder-1']);

    await tester.tap(find.byTooltip('删除任务夹并释放任务'));
    await tester.pumpAndSettle();
    expect(deleteCalls, ['folder-1']);
    expect(openCalls, ['folder-1']);
  });

  testWidgets('task folder progress background only shows while running', (
    tester,
  ) async {
    final folder = TaskFolder(
      id: 'folder-progress',
      name: '视频任务夹（1）',
      mediaKind: MediaKind.video,
      sortOrder: 0,
      createdAt: 1,
      updatedAt: 1,
    );
    final runningTask = testTask(fileName: 'inside.mp4').copyWith(
      id: 'inside',
      folderId: folder.id,
      folderSortOrder: 0,
      status: TaskStatus.running,
      progress: 0.6,
    );

    Widget buildTile(MediaTask task) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 640,
              child: TaskFolderListTile(
                folder: folder,
                tasks: [task],
                onOpenSettings: () {},
                onOpenContents: () {},
                onDelete: () {},
                onPause: () {},
                onRetry: () {},
                onShowLog: () {},
              ),
            ),
          ),
        ),
      );
    }

    final progressFinder = find.byKey(
      const ValueKey('task-folder-progress-folder-progress'),
    );
    await tester.pumpWidget(buildTile(runningTask));

    expect(progressFinder, findsOneWidget);
    expect(find.byTooltip('暂停任务夹任务'), findsOneWidget);

    final completedTask = runningTask.copyWith(
      status: TaskStatus.completed,
      progress: 1,
    );
    await tester.pumpWidget(buildTile(completedTask));
    await tester.pumpAndSettle();

    expect(progressFinder, findsNothing);
    expect(find.text('1 个任务 · 已完成 1 · 失败 0'), findsOneWidget);
    expect(find.byTooltip('重来任务夹终态任务'), findsOneWidget);
    expect(find.byTooltip('查看夹内任务日志'), findsOneWidget);
    expect(find.byTooltip('查看夹内任务'), findsOneWidget);
    expect(find.byTooltip('删除任务夹并释放任务'), findsOneWidget);

    final tileContainer = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(TaskFolderListTile),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(
      (tileContainer.decoration! as BoxDecoration).color,
      frameLeanLightColors.surface,
    );
  });

  testWidgets('folder content panel reuses task tile actions', (tester) async {
    final folder = TaskFolder(
      id: 'folder-1',
      name: '视频任务夹（1）',
      mediaKind: MediaKind.video,
      sortOrder: 0,
      createdAt: 1,
      updatedAt: 1,
    );
    final task = testTask(
      fileName: 'inside.mp4',
    ).copyWith(id: 'inside', folderId: folder.id, folderSortOrder: 0);
    var startCount = 0;
    var removeCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              TaskFolderContentPanel(
                visible: true,
                folder: folder,
                tasks: [task],
                thumbnailForTask: (_) => null,
                onClose: () {},
                onRemoveTask: (_) async {
                  removeCount += 1;
                },
                onStart: (_) {
                  startCount += 1;
                },
                onPause: (_) {},
                onRetry: (_) {},
                onRelink: (_) {},
                onShowLog: (_) {},
                onRevealOutput: (_) {},
                onReorder: (_, _) {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(MediaTaskListTile), findsOneWidget);
    expect(find.text('inside.mp4'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_circle_fill_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.remove_circle_outline_rounded));
    await tester.pump();

    expect(startCount, 1);
    expect(removeCount, 1);
  });

  testWidgets('folder task dragged onto scrim is removed in place', (
    tester,
  ) async {
    final folder = TaskFolder(
      id: 'folder-1',
      name: '视频任务夹（2）',
      mediaKind: MediaKind.video,
      sortOrder: 0,
      createdAt: 1,
      updatedAt: 1,
    );
    final firstTask = testTask(
      fileName: 'first.mp4',
    ).copyWith(id: 'first', folderId: folder.id, folderSortOrder: 0);
    final secondTask = testTask(
      fileName: 'second.mp4',
    ).copyWith(id: 'second', folderId: folder.id, folderSortOrder: 1);
    final removeCompleter = Completer<void>();
    final removeCalls = <String>[];
    final reorderCalls = <(int, int)>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              TaskFolderContentPanel(
                visible: true,
                folder: folder,
                tasks: [firstTask, secondTask],
                thumbnailForTask: (_) => null,
                onClose: () {},
                onRemoveTask: (task) {
                  removeCalls.add(task.id);
                  return removeCompleter.future;
                },
                onStart: (_) {},
                onPause: (_) {},
                onRetry: (_) {},
                onRelink: (_) {},
                onShowLog: (_) {},
                onRevealOutput: (_) {},
                onReorder: (oldIndex, newIndex) {
                  reorderCalls.add((oldIndex, newIndex));
                },
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(FrameLeanReorderableListView), findsOneWidget);
    expect(find.byType(ReorderableListView), findsNothing);
    final scrimFinder = find.byKey(const Key('task-folder-drop-scrim'));
    final beforeScrimColor =
        (tester.widget<AnimatedContainer>(scrimFinder).decoration!
                as BoxDecoration)
            .color;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.drag_indicator_rounded).first),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(const Offset(650, 300));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();

    final activeScrimColor =
        (tester.widget<AnimatedContainer>(scrimFinder).decoration!
                as BoxDecoration)
            .color;
    expect(activeScrimColor, isNot(beforeScrimColor));

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 20));
    expect(removeCalls, ['first']);
    expect(reorderCalls, isEmpty);
    expect(
      find.byKey(const Key('task-folder-accepted-drop-proxy')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('first.mp4'), findsNothing);
    expect(find.text('second.mp4'), findsOneWidget);
    expect(tester.takeException(), isNull);

    removeCompleter.complete();
    await tester.pump();
  });

  testWidgets('folder task dropped on panel header cancels removal', (
    tester,
  ) async {
    final folder = TaskFolder(
      id: 'folder-1',
      name: '视频任务夹（1）',
      mediaKind: MediaKind.video,
      sortOrder: 0,
      createdAt: 1,
      updatedAt: 1,
    );
    final task = testTask(
      fileName: 'inside.mp4',
    ).copyWith(id: 'inside', folderId: folder.id, folderSortOrder: 0);
    final removeCalls = <String>[];
    final reorderCalls = <(int, int)>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              TaskFolderContentPanel(
                visible: true,
                folder: folder,
                tasks: [task],
                thumbnailForTask: (_) => null,
                onClose: () {},
                onRemoveTask: (task) async {
                  removeCalls.add(task.id);
                },
                onStart: (_) {},
                onPause: (_) {},
                onRetry: (_) {},
                onRelink: (_) {},
                onShowLog: (_) {},
                onRevealOutput: (_) {},
                onReorder: (oldIndex, newIndex) {
                  reorderCalls.add((oldIndex, newIndex));
                },
              ),
            ],
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.drag_indicator_rounded)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(
      tester.getCenter(find.byIcon(Icons.folder_open_rounded)),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(removeCalls, isEmpty);
    expect(reorderCalls, isEmpty);
    expect(find.text('inside.mp4'), findsOneWidget);
  });

  testWidgets('folder task removal failure restores the task row', (
    tester,
  ) async {
    final folder = TaskFolder(
      id: 'folder-1',
      name: '视频任务夹（1）',
      mediaKind: MediaKind.video,
      sortOrder: 0,
      createdAt: 1,
      updatedAt: 1,
    );
    final task = testTask(
      fileName: 'inside.mp4',
    ).copyWith(id: 'inside', folderId: folder.id, folderSortOrder: 0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              TaskFolderContentPanel(
                visible: true,
                folder: folder,
                tasks: [task],
                thumbnailForTask: (_) => null,
                onClose: () {},
                onRemoveTask: (_) async {
                  throw StateError('save failed');
                },
                onStart: (_) {},
                onPause: (_) {},
                onRetry: (_) {},
                onRelink: (_) {},
                onShowLog: (_) {},
                onRevealOutput: (_) {},
                onReorder: (_, _) {},
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.remove_circle_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('inside.mp4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('running folder task cannot be dragged onto the scrim', (
    tester,
  ) async {
    final folder = TaskFolder(
      id: 'folder-1',
      name: '视频任务夹（1）',
      mediaKind: MediaKind.video,
      sortOrder: 0,
      createdAt: 1,
      updatedAt: 1,
    );
    final task = testTask(fileName: 'running.mp4').copyWith(
      id: 'running',
      folderId: folder.id,
      folderSortOrder: 0,
      status: TaskStatus.running,
    );
    final removeCalls = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              TaskFolderContentPanel(
                visible: true,
                folder: folder,
                tasks: [task],
                thumbnailForTask: (_) => null,
                onClose: () {},
                onRemoveTask: (task) async {
                  removeCalls.add(task.id);
                },
                onStart: (_) {},
                onPause: (_) {},
                onRetry: (_) {},
                onRelink: (_) {},
                onShowLog: (_) {},
                onRevealOutput: (_) {},
                onReorder: (_, _) {},
              ),
            ],
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.drag_indicator_rounded)),
    );
    await gesture.moveTo(const Offset(650, 300));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(removeCalls, isEmpty);
    expect(find.text('running.mp4'), findsOneWidget);
  });

  testWidgets(
    'folder reorder remains optimistic while persistence is pending',
    (tester) async {
      final folder = TaskFolder(
        id: 'folder-1',
        name: '视频任务夹（2）',
        mediaKind: MediaKind.video,
        sortOrder: 0,
        createdAt: 1,
        updatedAt: 1,
      );
      final firstTask = testTask(
        fileName: 'first.mp4',
      ).copyWith(id: 'first', folderId: folder.id, folderSortOrder: 0);
      final secondTask = testTask(
        fileName: 'second.mp4',
      ).copyWith(id: 'second', folderId: folder.id, folderSortOrder: 1);
      final reorderCompleter = Completer<void>();
      final reorderCalls = <(int, int)>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                TaskFolderContentPanel(
                  visible: true,
                  folder: folder,
                  tasks: [firstTask, secondTask],
                  thumbnailForTask: (_) => null,
                  onClose: () {},
                  onRemoveTask: (_) async {},
                  onStart: (_) {},
                  onPause: (_) {},
                  onRetry: (_) {},
                  onRelink: (_) {},
                  onShowLog: (_) {},
                  onRevealOutput: (_) {},
                  onReorder: (oldIndex, newIndex) {
                    reorderCalls.add((oldIndex, newIndex));
                    return reorderCompleter.future;
                  },
                ),
              ],
            ),
          ),
        ),
      );

      final firstTop = tester.getTopLeft(find.text('first.mp4')).dy;
      final dragHandles = find.byIcon(Icons.drag_indicator_rounded);
      final firstHandleCenter = tester.getCenter(dragHandles.first);
      final gesture = await tester.startGesture(
        tester.getCenter(dragHandles.last),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(firstHandleCenter);
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));

      expect(reorderCalls, isNotEmpty);
      expect(
        tester.getTopLeft(find.text('second.mp4')).dy,
        closeTo(firstTop, 0.1),
      );

      reorderCompleter.complete();
      await tester.pump();
    },
  );

  testWidgets('multi select mode shows checkbox and create folder FAB', (
    tester,
  ) async {
    var toggleModeCount = 0;
    var createFolderCount = 0;
    final task = testTask(fileName: 'outside.mp4').copyWith(id: 'outside');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkbenchShell(
            taskList: AsyncData([task]),
            taskFolders: const AsyncData([]),
            selectedTaskIds: {task.id},
            selectionMode: true,
            importEnabled: true,
            importDragging: false,
            hasRunningTask: false,
            queueActionInFlight: false,
            thumbnailForTask: (_) => null,
            onImportDraggingChanged: (_) {},
            onImportDrop: (_) {},
            onReorder: (_, _) {},
            onOpenTask: (_) {},
            onStart: (_) {},
            onPause: (_) {},
            onRemove: (_) {},
            onRetry: (_) {},
            onRelink: (_) {},
            onShowLog: (_) {},
            onRevealOutput: (_) {},
            onContextMenu: (_, _) {},
            onToggleSelectionMode: () {
              toggleModeCount += 1;
            },
            onToggleTaskSelection: (_) {},
            onSelectTasksWithRectangle: (_, {toggle = false}) {},
            onCreateFolderFromSelection: () {
              createFolderCount += 1;
            },
            onMoveTaskToFolder: (_, _) {},
            onOpenFolderSettings: (_) {},
            onOpenFolderContents: (_) {},
            onStartFolder: (_) {},
            onPauseFolder: (_) {},
            onRetryFolder: (_) {},
            onRelinkFolder: (_) {},
            onShowFolderLog: (_) {},
            onDeleteFolder: (_) {},
            onAddTasks: () {},
            onOpenSettings: () {},
            themeMode: AppThemeMode.light,
            onToggleThemeMode: () {},
            onOpenNotifications: () {},
            onClearTasks: () {},
            onPrimaryQueuePressed: () {},
          ),
        ),
      ),
    );

    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.text('已选 1'), findsOneWidget);
    expect(find.text('创建任务夹'), findsOneWidget);

    await tester.tap(find.byTooltip('退出多选'));
    await tester.pump();
    expect(toggleModeCount, 1);

    await tester.tap(find.text('创建任务夹'));
    await tester.pump();
    expect(createFolderCount, 1);
  });

  testWidgets(
    'task drag handle dropped on matching folder body moves instead of reorders',
    (tester) async {
      final moveCalls = <String>[];
      final reorderCalls = <(int oldIndex, int newIndex)>[];
      final folder = TaskFolder(
        id: 'folder-1',
        name: '视频任务夹（1）',
        mediaKind: MediaKind.video,
        sortOrder: 0,
        createdAt: 1,
        updatedAt: 1,
      );
      final folderTask = testTask(
        fileName: 'inside.mp4',
      ).copyWith(id: 'inside', folderId: folder.id, folderSortOrder: 0);
      final looseTask = testTask(
        fileName: 'outside.mp4',
      ).copyWith(id: 'outside', sortOrder: 1);

      await _pumpWorkbenchShellForDragTest(
        tester,
        tasks: [folderTask, looseTask],
        folders: [folder],
        onReorder: (oldIndex, newIndex) {
          reorderCalls.add((oldIndex, newIndex));
        },
        onMoveTaskToFolder: (task, folder) {
          moveCalls.add('${task.id}->${folder.id}');
        },
      );

      final taskDragHandle = find.byIcon(Icons.drag_indicator_rounded).last;
      final folderBody = find.byKey(
        const ValueKey('task-folder-drop-state-folder-1'),
      );
      final folderRectBeforeHover = tester.getRect(folderBody);
      final gesture = await tester.startGesture(
        tester.getCenter(taskDragHandle),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(
        Offset(
          folderRectBeforeHover.center.dx,
          folderRectBeforeHover.bottom - 8,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.getRect(folderBody).top,
        closeTo(folderRectBeforeHover.top, 0.1),
      );
      await gesture.moveTo(folderRectBeforeHover.center);
      await tester.pump(const Duration(milliseconds: 300));

      final hoveredFolder = tester.widget<AnimatedOpacity>(folderBody);
      final folderRectWhileHovered = tester.getRect(folderBody);
      expect(hoveredFolder.opacity, 1);
      expect(
        folderRectWhileHovered.top,
        closeTo(folderRectBeforeHover.top, 0.1),
      );
      expect(reorderCalls, isEmpty);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(moveCalls, ['outside->folder-1']);
      expect(reorderCalls, isEmpty);
    },
  );

  testWidgets(
    'task drag handle switches to reorder only after leaving folder body',
    (tester) async {
      final moveCalls = <String>[];
      final reorderCalls = <(int oldIndex, int newIndex)>[];
      final folder = TaskFolder(
        id: 'folder-1',
        name: '视频任务夹（1）',
        mediaKind: MediaKind.video,
        sortOrder: 0,
        createdAt: 1,
        updatedAt: 1,
      );
      final folderTask = testTask(
        fileName: 'inside.mp4',
      ).copyWith(id: 'inside', folderId: folder.id, folderSortOrder: 0);
      final firstLooseTask = testTask(
        fileName: 'first.mp4',
      ).copyWith(id: 'first', sortOrder: 1);
      final secondLooseTask = testTask(
        fileName: 'second.mp4',
      ).copyWith(id: 'second', sortOrder: 2);

      await _pumpWorkbenchShellForDragTest(
        tester,
        tasks: [folderTask, firstLooseTask, secondLooseTask],
        folders: [folder],
        onReorder: (oldIndex, newIndex) {
          reorderCalls.add((oldIndex, newIndex));
        },
        onMoveTaskToFolder: (task, folder) {
          moveCalls.add('${task.id}->${folder.id}');
        },
      );

      final taskDragHandles = find.byIcon(Icons.drag_indicator_rounded);
      final secondTaskDragHandle = taskDragHandles.last;
      final folderBody = find.byKey(
        const ValueKey('task-folder-drop-state-folder-1'),
      );
      final firstTaskText = find.text('first.mp4');
      final folderRectBeforeHover = tester.getRect(folderBody);
      final gesture = await tester.startGesture(
        tester.getCenter(secondTaskDragHandle),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(tester.getCenter(folderBody));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        tester.getRect(folderBody).top,
        closeTo(folderRectBeforeHover.top, 0.1),
      );
      expect(reorderCalls, isEmpty);

      await gesture.moveTo(tester.getCenter(firstTaskText));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      await gesture.moveTo(folderRectBeforeHover.center);
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      expect(
        tester.getRect(folderBody).top,
        closeTo(folderRectBeforeHover.top, 0.1),
      );
      expect(reorderCalls, isEmpty);

      await gesture.moveTo(tester.getCenter(firstTaskText));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(moveCalls, isEmpty);
      expect(reorderCalls, isNotEmpty);
    },
  );

  testWidgets(
    'task reorder keeps the dropped visual order while persistence catches up',
    (tester) async {
      final reorderCalls = <(int oldIndex, int newIndex)>[];
      final firstTask = testTask(
        fileName: 'first.mp4',
      ).copyWith(id: 'first', sortOrder: 0);
      final secondTask = testTask(
        fileName: 'second.mp4',
      ).copyWith(id: 'second', sortOrder: 1);
      final thirdTask = testTask(
        fileName: 'third.mp4',
      ).copyWith(id: 'third', sortOrder: 2);

      await _pumpWorkbenchShellForDragTest(
        tester,
        tasks: [firstTask, secondTask, thirdTask],
        folders: const [],
        onReorder: (oldIndex, newIndex) {
          reorderCalls.add((oldIndex, newIndex));
        },
      );

      final slotTops = [
        tester.getTopLeft(find.text('first.mp4')).dy,
        tester.getTopLeft(find.text('second.mp4')).dy,
        tester.getTopLeft(find.text('third.mp4')).dy,
      ];
      final taskDragHandles = find.byIcon(Icons.drag_indicator_rounded);
      final gesture = await tester.startGesture(
        tester.getCenter(taskDragHandles.last),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(tester.getCenter(find.text('first.mp4')));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));

      expect(reorderCalls, hasLength(1));
      final (oldIndex, newIndex) = reorderCalls.single;
      final visualIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
      expect(
        tester.getTopLeft(find.text('third.mp4')).dy,
        closeTo(slotTops[visualIndex], 0.1),
      );
    },
  );

  testWidgets('task rows never use selection borders', (tester) async {
    final task = testTask(fileName: 'ordinary.mp3').copyWith(id: 'ordinary');

    await _pumpWorkbenchShellForDragTest(
      tester,
      tasks: [task],
      folders: const [],
      selectedTaskIds: {task.id},
      selectionMode: true,
    );

    final tile = find.byType(MediaTaskListTile);
    final animatedContainer = tester.widget<AnimatedContainer>(
      find.descendant(of: tile, matching: find.byType(AnimatedContainer)),
    );
    final decoration = animatedContainer.foregroundDecoration! as BoxDecoration;
    expect(decoration.border!.top.color, frameLeanLightColors.border);
    expect(decoration.border!.top.width, 1);
  });

  testWidgets('task drag handle dropped on folder edge keeps reorder', (
    tester,
  ) async {
    final moveCalls = <String>[];
    final reorderCalls = <(int oldIndex, int newIndex)>[];
    final folder = TaskFolder(
      id: 'folder-1',
      name: '视频任务夹（1）',
      mediaKind: MediaKind.video,
      sortOrder: 0,
      createdAt: 1,
      updatedAt: 1,
    );
    final folderTask = testTask(
      fileName: 'inside.mp4',
    ).copyWith(id: 'inside', folderId: folder.id, folderSortOrder: 0);
    final looseTask = testTask(
      fileName: 'outside.mp4',
    ).copyWith(id: 'outside', sortOrder: 1);

    await _pumpWorkbenchShellForDragTest(
      tester,
      tasks: [folderTask, looseTask],
      folders: [folder],
      onReorder: (oldIndex, newIndex) {
        reorderCalls.add((oldIndex, newIndex));
      },
      onMoveTaskToFolder: (task, folder) {
        moveCalls.add('${task.id}->${folder.id}');
      },
    );

    final taskDragHandle = find.byIcon(Icons.drag_indicator_rounded).last;
    final folderRect = tester.getRect(
      find.byKey(const ValueKey('task-folder-drop-state-folder-1')),
    );
    final folderTopEdge = Offset(folderRect.center.dx, folderRect.top + 8);
    final gesture = await tester.startGesture(tester.getCenter(taskDragHandle));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(folderTopEdge);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(moveCalls, isEmpty);
    expect(reorderCalls, isNotEmpty);
  });

  testWidgets(
    'different-kind folder disables drop and remains a reorder target',
    (tester) async {
      final moveCalls = <String>[];
      final reorderCalls = <(int oldIndex, int newIndex)>[];
      final folder = TaskFolder(
        id: 'image-folder',
        name: '图片任务夹（1）',
        mediaKind: MediaKind.image,
        sortOrder: 0,
        createdAt: 1,
        updatedAt: 1,
      );
      final folderTask = imageTask().copyWith(
        id: 'inside-image',
        folderId: folder.id,
        folderSortOrder: 0,
      );
      final looseTask = testTask(
        fileName: 'outside.mp4',
      ).copyWith(id: 'outside', sortOrder: 1);

      await _pumpWorkbenchShellForDragTest(
        tester,
        tasks: [folderTask, looseTask],
        folders: [folder],
        onReorder: (oldIndex, newIndex) {
          reorderCalls.add((oldIndex, newIndex));
        },
        onMoveTaskToFolder: (task, folder) {
          moveCalls.add('${task.id}->${folder.id}');
        },
      );

      final taskDragHandle = find.byIcon(Icons.drag_indicator_rounded).last;
      final folderBody = find.byKey(
        const ValueKey('task-folder-drop-state-image-folder'),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(taskDragHandle),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(tester.getCenter(folderBody));
      await tester.pump();

      final disabledState = tester.widget<AnimatedOpacity>(folderBody);
      expect(disabledState.opacity, lessThan(1));

      await gesture.up();
      await tester.pumpAndSettle();

      expect(moveCalls, isEmpty);
      expect(reorderCalls, isNotEmpty);
    },
  );

  testWidgets('notification badge can be hidden without losing unread count', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkbenchTopBar(
            themeMode: AppThemeMode.light,
            onToggleThemeMode: () {},
            onOpenNotifications: () {},
            unreadNotificationCount: 3,
            showNotificationBadge: false,
          ),
        ),
      ),
    );

    expect(find.byTooltip('通知中心'), findsOneWidget);
    expect(find.byKey(const Key('notification-unread-badge')), findsNothing);
  });

  testWidgets('task list drag handle starts reorder without layout exception', (
    tester,
  ) async {
    final reorderCalls = <(int oldIndex, int newIndex)>[];
    final firstTask = testTask(
      fileName: 'first.mp4',
    ).copyWith(id: 'task-1', sortOrder: 0);
    final secondTask = testTask(
      fileName: 'second.mp4',
    ).copyWith(id: 'task-2', sortOrder: 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkbenchShell(
            taskList: AsyncData([firstTask, secondTask]),
            taskFolders: const AsyncData([]),
            selectedTaskIds: const {},
            selectionMode: false,
            importEnabled: true,
            importDragging: false,
            hasRunningTask: false,
            queueActionInFlight: false,
            thumbnailForTask: (_) => null,
            onImportDraggingChanged: (_) {},
            onImportDrop: (_) {},
            onReorder: (oldIndex, newIndex) {
              reorderCalls.add((oldIndex, newIndex));
            },
            onOpenTask: (_) {},
            onStart: (_) {},
            onPause: (_) {},
            onRemove: (_) {},
            onRetry: (_) {},
            onRelink: (_) {},
            onShowLog: (_) {},
            onRevealOutput: (_) {},
            onContextMenu: (_, _) {},
            onToggleSelectionMode: () {},
            onToggleTaskSelection: (_) {},
            onSelectTasksWithRectangle: (_, {toggle = false}) {},
            onCreateFolderFromSelection: () {},
            onMoveTaskToFolder: (_, _) {},
            onOpenFolderSettings: (_) {},
            onOpenFolderContents: (_) {},
            onStartFolder: (_) {},
            onPauseFolder: (_) {},
            onRetryFolder: (_) {},
            onRelinkFolder: (_) {},
            onShowFolderLog: (_) {},
            onDeleteFolder: (_) {},
            onAddTasks: () {},
            onOpenSettings: () {},
            themeMode: AppThemeMode.light,
            onToggleThemeMode: () {},
            onOpenNotifications: () {},
            onClearTasks: () {},
            onPrimaryQueuePressed: () {},
          ),
        ),
      ),
    );

    final firstDragHandle = find.byIcon(Icons.drag_indicator_rounded).first;
    final gesture = await tester.startGesture(
      tester.getCenter(firstDragHandle),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 150));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(reorderCalls, isNotEmpty);
  });
}

Future<void> _pumpWorkbenchShellForDragTest(
  WidgetTester tester, {
  required List<MediaTask> tasks,
  required List<TaskFolder> folders,
  Set<String> selectedTaskIds = const {},
  bool selectionMode = false,
  void Function(int oldIndex, int newIndex)? onReorder,
  void Function(MediaTask task, TaskFolder folder)? onMoveTaskToFolder,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WorkbenchShell(
          taskList: AsyncData(tasks),
          taskFolders: AsyncData(folders),
          selectedTaskIds: selectedTaskIds,
          selectionMode: selectionMode,
          importEnabled: true,
          importDragging: false,
          hasRunningTask: false,
          queueActionInFlight: false,
          thumbnailForTask: (_) => null,
          onImportDraggingChanged: (_) {},
          onImportDrop: (_) {},
          onReorder: onReorder ?? (_, _) {},
          onOpenTask: (_) {},
          onStart: (_) {},
          onPause: (_) {},
          onRemove: (_) {},
          onRetry: (_) {},
          onRelink: (_) {},
          onShowLog: (_) {},
          onRevealOutput: (_) {},
          onContextMenu: (_, _) {},
          onToggleSelectionMode: () {},
          onToggleTaskSelection: (_) {},
          onSelectTasksWithRectangle: (_, {toggle = false}) {},
          onCreateFolderFromSelection: () {},
          onMoveTaskToFolder: onMoveTaskToFolder ?? (_, _) {},
          onOpenFolderSettings: (_) {},
          onOpenFolderContents: (_) {},
          onStartFolder: (_) {},
          onPauseFolder: (_) {},
          onRetryFolder: (_) {},
          onRelinkFolder: (_) {},
          onShowFolderLog: (_) {},
          onDeleteFolder: (_) {},
          onAddTasks: () {},
          onOpenSettings: () {},
          themeMode: AppThemeMode.light,
          onToggleThemeMode: () {},
          onOpenNotifications: () {},
          onClearTasks: () {},
          onPrimaryQueuePressed: () {},
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
MediaTask testTask({
  String fileName = 'source.mp4',
  VideoTaskConfig? config,
  TaskStatus? status,
  MediaAnalysisResult? analysisResult,
  bool hasAnalysisResult = true,
}) {
  return MediaTask(
    id: 'task-1',
    inputPath: '/videos/$fileName',
    fileName: fileName,
    mediaKind: MediaKind.video,
    purpose: TaskPurpose.compression,
    status: status ?? TaskStatus.ready,
    config: config ?? VideoTaskConfig.initial(),
    progress: 0,
    sortOrder: 0,
    createdAt: 1,
    sourceFileFingerprint: const SourceFileFingerprint(
      fileSize: 100 * 1024 * 1024,
      lastModifiedAt: 1,
    ),
    analysisResult: hasAnalysisResult
        ? analysisResult ??
              MediaAnalysisResult(
                durationMs: 60000,
                videoWidth: 3840,
                videoHeight: 2160,
                videoCodec: 'h264',
                videoBitrate: 12000000,
                audioBitrate: 128000,
              )
        : null,
  );
}

MediaTask imageTask({ImageProcessingConfig? config}) {
  return MediaTask(
    id: 'image-task',
    inputPath: '/images/source.png',
    fileName: 'source.png',
    mediaKind: MediaKind.image,
    purpose: TaskPurpose.compression,
    status: TaskStatus.ready,
    config: MediaTaskConfig.initialImage().copyWith(
      image: config ?? ImageProcessingConfig.initial(),
    ),
    progress: 0,
    sortOrder: 0,
    createdAt: 1,
    sourceFileFingerprint: const SourceFileFingerprint(
      fileSize: 2 * 1024 * 1024,
      lastModifiedAt: 1,
    ),
    analysisResult: MediaAnalysisResult(
      imageWidth: 1200,
      imageHeight: 800,
      imageCodec: 'png',
      imagePixelFormat: 'rgba',
      imageBitDepth: 8,
      containerFormat: 'png_pipe',
    ),
  );
}

MediaTask audioTask({AudioProcessingConfig? config}) {
  return MediaTask(
    id: 'audio-task',
    inputPath: '/audio/source.wav',
    fileName: 'source.wav',
    mediaKind: MediaKind.audio,
    purpose: TaskPurpose.compression,
    status: TaskStatus.ready,
    config: MediaTaskConfig.initialAudio().copyWith(
      audio: config ?? AudioProcessingConfig.initial(),
    ),
    progress: 0,
    sortOrder: 0,
    createdAt: 1,
    sourceFileFingerprint: const SourceFileFingerprint(
      fileSize: 6 * 1024 * 1024,
      lastModifiedAt: 1,
    ),
    analysisResult: MediaAnalysisResult(
      durationMs: 42000,
      audioCodec: 'pcm_s16le',
      audioBitrate: 1411200,
      audioChannels: 2,
      audioSampleRate: 44100,
      containerFormat: 'wav',
    ),
  );
}
