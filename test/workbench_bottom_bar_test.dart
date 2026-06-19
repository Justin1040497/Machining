import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/features/workbench/pages/workbench_page/layout/bottom_bar.dart';

void main() {
  testWidgets('bottom bar exposes settings gear', (tester) async {
    var opened = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkbenchBottomBar(
            taskList: const AsyncData<List<MediaTask>>([]),
            hasRunningTask: false,
            queueActionInFlight: false,
            selectionMode: false,
            selectionEnabled: false,
            onAddFiles: () {},
            onAddFolder: () {},
            onToggleSelectionMode: () {},
            onOpenSettings: () {
              opened = true;
            },
            onClearTasks: () {},
            onPrimaryQueuePressed: () {},
          ),
        ),
      ),
    );

    expect(find.byTooltip('设置'), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);

    await tester.tap(find.byTooltip('设置'));
    await tester.pump();

    expect(opened, isTrue);
  });
}
