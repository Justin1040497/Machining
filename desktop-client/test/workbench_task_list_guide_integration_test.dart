import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/features/workbench/pages/workbench_page/layout/task_list_card.dart';

void main() {
  testWidgets('double tapping the empty background invokes task import', (
    tester,
  ) async {
    var importCount = 0;
    await tester.pumpWidget(
      _buildHarness(tasks: const [], onImport: () => importCount += 1),
    );

    await _doubleTapAt(tester, const Offset(450, 300));

    expect(importCount, 1);
  });

  testWidgets('double tapping unused background imports when tasks exist', (
    tester,
  ) async {
    var importCount = 0;
    await tester.pumpWidget(
      _buildHarness(tasks: [_mediaTask()], onImport: () => importCount += 1),
    );
    await tester.pumpAndSettle();

    await _doubleTapAt(tester, const Offset(450, 90));
    expect(importCount, 0);

    await _doubleTapAt(tester, const Offset(450, 500));
    expect(importCount, 1);
  });
}

Widget _buildHarness({
  required List<MediaTask> tasks,
  required VoidCallback onImport,
}) {
  return ProviderScope(
    child: MaterialApp(
      home: SizedBox(
        width: 900,
        height: 600,
        child: WorkbenchTaskListCard(
          taskList: AsyncData(tasks),
          taskFolders: const AsyncData(<TaskFolder>[]),
          selectedTaskIds: const {},
          selectionMode: false,
          thumbnailForTask: (_) => null,
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
          onFolderContextMenu: (_, _) {},
          onToggleTaskSelection: (_) {},
          onSelectTasksWithRectangle: (_, {toggle = false}) {},
          onMoveTaskToFolder: (_, _) {},
          onOpenFolderSettings: (_) {},
          onOpenFolderContents: (_) {},
          onStartFolder: (_) {},
          onPauseFolder: (_) {},
          onRetryFolder: (_) {},
          onRelinkFolder: (_) {},
          onShowFolderLog: (_) {},
          onDeleteFolder: (_) {},
          onDoubleTapBackground: onImport,
        ),
      ),
    ),
  );
}

Future<void> _doubleTapAt(WidgetTester tester, Offset position) async {
  await tester.tapAt(position);
  await tester.pump(const Duration(milliseconds: 60));
  await tester.tapAt(position);
  await tester.pumpAndSettle();
}

MediaTask _mediaTask() {
  return MediaTask(
    id: 'task-1',
    inputPath: '/videos/task-1.mp4',
    fileName: 'task-1.mp4',
    mediaKind: MediaKind.video,
    purpose: TaskPurpose.compression,
    status: TaskStatus.ready,
    config: VideoTaskConfig.initial(),
    progress: 0,
    sortOrder: 0,
    createdAt: 1,
  );
}
