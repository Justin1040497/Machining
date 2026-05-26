import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machining/features/workbench/pages/workbench_page/configuration/workbench_models.dart';
import 'package:machining/features/workbench/pages/workbench_page/dialogs/clear_tasks_dialog.dart';
import 'package:machining/features/workbench/pages/workbench_page/dialogs/compression_confirmation_dialog.dart';
import 'package:machining/features/workbench/pages/workbench_page/dialogs/import_failure_dialog.dart';
import 'package:machining/features/workbench/pages/workbench_page/dialogs/task_rename_dialog.dart';
import 'package:machining/features/workbench/pages/workbench_page/dialogs/workbench_dialog_widgets.dart';

void main() {
  testWidgets('confirmation dialogs use workbench dialog styling', (
    tester,
  ) async {
    await _pumpDialog(
      tester,
      const CompressionConfirmationDialog(message: '该视频已经压缩过'),
    );

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(WorkbenchDialogFrame), findsOneWidget);
    expect(find.text('确认继续压缩'), findsOneWidget);
    expect(find.text('继续压缩'), findsOneWidget);
  });

  testWidgets('task management dialogs use workbench dialog styling', (
    tester,
  ) async {
    await _pumpDialog(tester, const ClearTasksDialog());

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(WorkbenchDialogFrame), findsOneWidget);
    expect(find.text('清空列表'), findsOneWidget);
  });

  testWidgets('rename dialog uses workbench dialog styling', (tester) async {
    await _pumpDialog(tester, const TaskRenameDialog(initialName: 'clip.mp4'));

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(WorkbenchDialogFrame), findsOneWidget);
    expect(find.text('任务重命名'), findsOneWidget);
    expect(find.text('clip.mp4'), findsOneWidget);
  });

  testWidgets('import failure dialog uses workbench dialog styling', (
    tester,
  ) async {
    await _pumpDialog(
      tester,
      const ImportFailureDialog(
        failures: [
          DroppedImportFailure(path: '/tmp/not-video.txt', reason: '不支持的格式'),
        ],
      ),
    );

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(WorkbenchDialogFrame), findsOneWidget);
    expect(find.text('导入失败日志'), findsOneWidget);
    expect(find.textContaining('not-video.txt'), findsOneWidget);
  });
}

Future<void> _pumpDialog(WidgetTester tester, Widget dialog) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: dialog)));
}
