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
      ProviderScope(
        child: MaterialApp(
          home: SizedBox(
            width: 900,
            height: 600,
            child: WorkbenchTaskListCard(
              taskList: const AsyncData(<MediaTask>[]),
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
              onDoubleTapBackground: () => importCount += 1,
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(450, 300));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(const Offset(450, 300));
    await tester.pumpAndSettle();

    expect(importCount, 1);
  });
}
