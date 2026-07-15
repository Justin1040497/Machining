import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/features/workbench/guide/arrow/doodle_arrow.dart';
import 'package:framelean/features/workbench/guide/models/guide_geometry.dart';
import 'package:framelean/features/workbench/guide/workbench_background_guide_system.dart';

void main() {
  testWidgets('empty queue renders import content and add-button arrow', (
    tester,
  ) async {
    await tester.pumpWidget(const _GuideHarness(initialTaskCount: 0));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.text('可以直接把文件拖进来\n或者双击背景板\n又或者点击左小角的"+"号来添加媒体任务'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('empty-queue-guide-content')),
      findsOneWidget,
    );
    final importContentRect = tester.getRect(
      find.byKey(const ValueKey('empty-queue-guide-content')),
    );
    expect(importContentRect.center.dx, closeTo(400, 0.1));
    expect(importContentRect.center.dy, closeTo(319, 0.1));
    expect(
      find.byKey(const ValueKey('empty-queue-guide-icon')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('add-button-guide-arrow')),
      findsOneWidget,
    );
    final addArrow = tester.widget<DoodleArrow>(
      find.byKey(const ValueKey('add-button-guide-arrow')),
    );
    expect(
      (addArrow.targetPoint - addArrow.startPoint).distance,
      inInclusiveRange(145, 165),
    );
    expect(addArrow.maxLength, 180);
    expect(addArrow.curveBias, const Offset(0, -72));
    final guideLayer = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('workbench-background-guide-layer')),
    );
    expect(guideLayer.opacity, 0.50);
  });

  testWidgets('task workspace renders both guide content groups', (
    tester,
  ) async {
    await tester.pumpWidget(const _GuideHarness(initialTaskCount: 1));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('这里可以操作任务\n点击任务块可以打开配置'), findsOneWidget);
    expect(find.text('点击这里全部开始'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('task-operation-guide-arrow')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('start-all-guide-arrow')), findsOneWidget);

    final taskArrow = tester.widget<DoodleArrow>(
      find.byKey(const ValueKey('task-operation-guide-arrow')),
    );
    final taskText = tester.widget<Positioned>(
      find.byKey(const ValueKey('task-operation-guide-text')),
    );
    final startArrow = tester.widget<DoodleArrow>(
      find.byKey(const ValueKey('start-all-guide-arrow')),
    );
    final startText = tester.widget<Positioned>(
      find.byKey(const ValueKey('start-all-guide-text')),
    );
    final taskTextWidget = tester.widget<Text>(
      find.text('这里可以操作任务\n点击任务块可以打开配置'),
    );
    expect(taskArrow.targetPoint.dx - taskArrow.startPoint.dx, 185);
    expect(
      (taskArrow.targetPoint - taskArrow.startPoint).distance,
      inInclusiveRange(185, 220),
    );
    expect(
      (startArrow.targetPoint - startArrow.startPoint).distance,
      inInclusiveRange(185, 220),
    );
    expect(taskArrow.maxLength, startArrow.maxLength);
    expect(taskArrow.maxLength, 245);
    expect(taskArrow.curveBias.dy, -startArrow.curveBias.dy);
    expect(taskArrow.startPoint.dx - (taskText.left! + taskText.width!), 14);
    expect(taskTextWidget.textAlign, TextAlign.right);
    expect(startText.left! - startArrow.startPoint.dx, 14);
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
    expect(
      find.text('可以直接把文件拖进来\n或者双击背景板\n又或者点击左小角的"+"号来添加媒体任务'),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 449));
    expect(find.text('这里可以操作任务\n点击任务块可以打开配置'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.text('这里可以操作任务\n点击任务块可以打开配置'), findsOneWidget);
  });

  testWidgets('scrollable task list hides task guide content', (tester) async {
    await tester.pumpWidget(
      const _GuideHarness(initialTaskCount: 3, hasScrollableContent: true),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('点击这里全部开始'), findsNothing);
  });

  testWidgets('limited task space keeps only the start-all guide', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _GuideHarness(initialTaskCount: 3, lastTaskTop: 230),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('这里可以操作任务\n点击任务块可以打开配置'), findsNothing);
    expect(find.text('点击这里全部开始'), findsOneWidget);
  });

  testWidgets('two task guides use separated clip lanes', (tester) async {
    await tester.pumpWidget(
      const _GuideHarness(initialTaskCount: 3, lastTaskTop: 112),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    final taskArrow = tester.widget<DoodleArrow>(
      find.byKey(const ValueKey('task-operation-guide-arrow')),
    );
    final startArrow = tester.widget<DoodleArrow>(
      find.byKey(const ValueKey('start-all-guide-arrow')),
    );
    expect(taskArrow.clipRect, isNotNull);
    expect(startArrow.clipRect, isNotNull);
    expect(taskArrow.clipRect!.overlaps(startArrow.clipRect!), isFalse);
    expect(startArrow.clipRect!.top - taskArrow.clipRect!.bottom, 28);
  });

  testWidgets(
    'resizing transitions both to start-only to hidden without replaying start',
    (tester) async {
      final key = GlobalKey<_GuideHarnessState>();
      await tester.pumpWidget(
        _GuideHarness(key: key, initialTaskCount: 3, lastTaskTop: 112),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      final startArrowState = tester.state(
        find.byKey(const ValueKey('start-all-guide-arrow')),
      );

      key.currentState!.setLastTaskTop(230);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 181));

      expect(find.text('这里可以操作任务\n点击任务块可以打开配置'), findsNothing);
      expect(find.text('点击这里全部开始'), findsOneWidget);
      expect(
        tester.state(find.byKey(const ValueKey('start-all-guide-arrow'))),
        same(startArrowState),
      );

      key.currentState!.setLastTaskTop(400);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 351));
      await tester.pump();

      expect(find.text('点击这里全部开始'), findsNothing);
    },
  );

  testWidgets('loaded empty state fades in even when geometry is unchanged', (
    tester,
  ) async {
    final key = GlobalKey<_GuideHarnessState>();
    await tester.pumpWidget(_GuideHarness(key: key, initialTaskCount: null));
    await tester.pump();
    expect(
      find.text('可以直接把文件拖进来\n或者双击背景板\n又或者点击左小角的"+"号来添加媒体任务'),
      findsNothing,
    );

    key.currentState!.setTaskCount(0);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(
      find.text('可以直接把文件拖进来\n或者双击背景板\n又或者点击左小角的"+"号来添加媒体任务'),
      findsOneWidget,
    );
  });
}

class _GuideHarness extends StatefulWidget {
  const _GuideHarness({
    super.key,
    required this.initialTaskCount,
    this.hasScrollableContent = false,
    this.lastTaskTop = 80,
  });

  final int? initialTaskCount;
  final bool hasScrollableContent;
  final double lastTaskTop;

  @override
  State<_GuideHarness> createState() => _GuideHarnessState();
}

class _GuideHarnessState extends State<_GuideHarness> {
  late int? _taskCount = widget.initialTaskCount;
  late double _lastTaskTop = widget.lastTaskTop;

  void setTaskCount(int value) => setState(() => _taskCount = value);

  void setLastTaskTop(double value) => setState(() => _lastTaskTop = value);

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
                        top: _lastTaskTop,
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
