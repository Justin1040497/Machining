import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/features/workbench/guide/models/guide_geometry.dart';
import 'package:framelean/features/workbench/guide/workbench_background_guide_system.dart';

void main() {
  testWidgets('empty queue renders import content and add-button arrow', (
    tester,
  ) async {
    await tester.pumpWidget(const _GuideHarness(initialTaskCount: 0));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('拖拽或双击背景板来添加任务'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('empty-queue-guide-icon')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('add-button-guide-arrow')),
      findsOneWidget,
    );
  });

  testWidgets('task workspace renders both guide content groups', (
    tester,
  ) async {
    await tester.pumpWidget(const _GuideHarness(initialTaskCount: 1));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('这里可以操作任务，\n点击任务块可以打开配置'), findsOneWidget);
    expect(find.text('点击这里全部开始'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('task-operation-guide-arrow')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('start-all-guide-arrow')), findsOneWidget);
  });

  testWidgets('scene swap fades out, waits, then builds the next scene', (
    tester,
  ) async {
    final key = GlobalKey<_GuideHarnessState>();
    await tester.pumpWidget(_GuideHarness(key: key, initialTaskCount: 0));
    await tester.pump();
    await tester.pumpAndSettle();

    key.currentState!.setTaskCount(1);
    await tester.pump();
    expect(find.text('拖拽或双击背景板来添加任务'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 449));
    expect(find.text('这里可以操作任务，\n点击任务块可以打开配置'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text('这里可以操作任务，\n点击任务块可以打开配置'), findsOneWidget);
  });

  testWidgets('scrollable task list hides task guide content', (tester) async {
    await tester.pumpWidget(
      const _GuideHarness(initialTaskCount: 3, hasScrollableContent: true),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('点击这里全部开始'), findsNothing);
  });

  testWidgets('loaded empty state fades in even when geometry is unchanged', (
    tester,
  ) async {
    final key = GlobalKey<_GuideHarnessState>();
    await tester.pumpWidget(_GuideHarness(key: key, initialTaskCount: null));
    await tester.pump();
    expect(find.text('拖拽或双击背景板来添加任务'), findsNothing);

    key.currentState!.setTaskCount(0);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('拖拽或双击背景板来添加任务'), findsOneWidget);
  });
}

class _GuideHarness extends StatefulWidget {
  const _GuideHarness({
    super.key,
    required this.initialTaskCount,
    this.hasScrollableContent = false,
  });

  final int? initialTaskCount;
  final bool hasScrollableContent;

  @override
  State<_GuideHarness> createState() => _GuideHarnessState();
}

class _GuideHarnessState extends State<_GuideHarness> {
  late int? _taskCount = widget.initialTaskCount;

  void setTaskCount(int value) => setState(() => _taskCount = value);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 900,
            height: 700,
            child: WorkbenchGuideAnchorHost(
              taskCount: _taskCount,
              builder: (context, anchors, onListMetricsChanged, guideLayer) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  onListMetricsChanged(
                    GuideListMetrics(
                      hasScrollableContent: widget.hasScrollableContent,
                    ),
                  );
                });
                return Stack(
                  children: [
                    guideLayer,
                    Positioned(
                      left: 0,
                      top: 0,
                      right: 0,
                      height: 638,
                      child: SizedBox(key: anchors.listViewportKey),
                    ),
                    if ((_taskCount ?? 0) > 0)
                      Positioned(
                        left: 24,
                        top: 80,
                        width: 700,
                        height: 72,
                        child: SizedBox(key: anchors.lastTaskKey),
                      ),
                    Positioned(
                      left: 20,
                      top: 650,
                      width: 36,
                      height: 36,
                      child: SizedBox(key: anchors.addButtonKey),
                    ),
                    Positioned(
                      left: 416,
                      top: 610,
                      width: 68,
                      height: 68,
                      child: SizedBox(key: anchors.startButtonKey),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
