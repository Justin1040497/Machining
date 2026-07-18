import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/app/presentation/widgets/app_dialog_frame.dart';
import 'package:framelean/app/presentation/widgets/confirm_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_models.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/confirm/import_failure_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task/task_rename_dialog.dart';

void main() {
  testWidgets('confirmation dialogs use app dialog styling', (tester) async {
    await _pumpDialog(
      tester,
      const ConfirmDialog(
        title: '确认继续压缩',
        body: '该视频已经压缩过\n继续后会使用更激进的压缩策略。',
        confirmLabel: '继续压缩',
        confirmWidth: 96,
      ),
    );

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(AppDialogFrame), findsOneWidget);
    expect(find.text('确认继续压缩'), findsOneWidget);
    expect(find.text('继续压缩'), findsOneWidget);
  });

  testWidgets('clear tasks confirm dialog uses app dialog styling', (
    tester,
  ) async {
    await _pumpDialog(
      tester,
      const ConfirmDialog(
        title: '清空列表',
        body: '确定要清空所有任务和任务夹吗？',
        confirmLabel: '清空',
      ),
    );

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(AppDialogFrame), findsOneWidget);
    expect(find.text('清空列表'), findsOneWidget);
  });

  testWidgets('rename dialog uses app dialog styling', (tester) async {
    await _pumpDialog(tester, const TaskRenameDialog(initialName: 'clip.mp4'));

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(AppDialogFrame), findsOneWidget);
    expect(find.text('任务重命名'), findsOneWidget);
    expect(find.text('clip.mp4'), findsOneWidget);
  });

  testWidgets('import failure dialog uses app dialog styling', (tester) async {
    await _pumpDialog(
      tester,
      const ImportFailureDialog(
        successCount: 0,
        failures: [
          DroppedImportFailure(path: '/tmp/not-video.txt', reason: '不支持的格式'),
        ],
      ),
    );

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(AppDialogFrame), findsOneWidget);
    expect(find.text('导入结果'), findsOneWidget);
    expect(find.text('not-video.txt'), findsOneWidget);
  });
}

Future<void> _pumpDialog(WidgetTester tester, Widget dialog) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: dialog)));
}
