import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/app/presentation/widgets/reorderable/framelean_reorderable_list_view.dart';

void main() {
  testWidgets('reports native reorder indices and drag updates', (
    tester,
  ) async {
    final reorderCalls = <(int, int)>[];
    final updates = <FrameLeanReorderGapDetails>[];

    await _pumpList(
      tester,
      onReorder: (oldIndex, newIndex) {
        reorderCalls.add((oldIndex, newIndex));
      },
      onReorderUpdate: updates.add,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('handle-a'))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(find.text('C')));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(updates, isNotEmpty);
    expect(reorderCalls, [(0, 2)]);
  });

  testWidgets('supports move hold and restore-origin gap behaviors', (
    tester,
  ) async {
    var behavior = FrameLeanReorderGapBehavior.move;

    await _pumpList(tester, onReorder: (_, _) {}, gapBehavior: (_) => behavior);

    final firstTop = tester.getTopLeft(find.text('A')).dy;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('handle-c'))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(tester.getCenter(find.text('B')));
    await tester.pump(const Duration(milliseconds: 300));
    final movedTop = tester.getTopLeft(find.text('A')).dy;

    behavior = FrameLeanReorderGapBehavior.hold;
    await gesture.moveTo(Offset(100, firstTop + 2));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getTopLeft(find.text('A')).dy, closeTo(movedTop, 0.1));

    behavior = FrameLeanReorderGapBehavior.restoreOrigin;
    await gesture.moveBy(const Offset(0, 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getTopLeft(find.text('A')).dy, closeTo(firstTop, 0.1));

    await gesture.cancel();
    await tester.pumpAndSettle();
  });

  testWidgets('accepted external drop can synchronously remove its source', (
    tester,
  ) async {
    final items = ['A', 'B', 'C'];
    final reorderCalls = <(int, int)>[];
    var acceptedCount = 0;
    var acceptedDecoratorBuildCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  key: const Key('list-bounds'),
                  width: 260,
                  height: 240,
                  child: FrameLeanReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    allowCrossAxisDrag: true,
                    itemCount: items.length,
                    onReorder: (oldIndex, newIndex) {
                      reorderCalls.add((oldIndex, newIndex));
                    },
                    gapBehavior: (details) =>
                        tester
                            .getRect(find.byKey(const Key('list-bounds')))
                            .contains(details.globalPosition)
                        ? FrameLeanReorderGapBehavior.move
                        : FrameLeanReorderGapBehavior.restoreOrigin,
                    onDrop: (details) {
                      final listRect = tester.getRect(
                        find.byKey(const Key('list-bounds')),
                      );
                      if (listRect.contains(details.globalPosition)) {
                        return FrameLeanReorderDropDisposition.reorder;
                      }
                      acceptedCount += 1;
                      setState(() {
                        items.removeAt(details.oldIndex);
                      });
                      return FrameLeanReorderDropDisposition.accepted;
                    },
                    acceptedDropProxyDecorator: (child, index, animation) {
                      acceptedDecoratorBuildCount += 1;
                      return FadeTransition(
                        key: const Key('accepted-drop-proxy'),
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: 0.94,
                            end: 1,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    itemBuilder: (context, index) {
                      return _TestItem(
                        key: ValueKey(items[index]),
                        label: items[index],
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    final listRect = tester.getRect(find.byKey(const Key('list-bounds')));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('handle-a'))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(Offset(listRect.right + 80, listRect.center.dy));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 20));

    expect(acceptedCount, 1);
    expect(reorderCalls, isEmpty);
    expect(items, ['B', 'C']);
    expect(acceptedDecoratorBuildCount, greaterThan(0));
    expect(tester.takeException(), isNull);

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('accepted-drop-proxy')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelled external drop restores without reordering', (
    tester,
  ) async {
    final reorderCalls = <(int, int)>[];
    await _pumpList(
      tester,
      onReorder: (oldIndex, newIndex) {
        reorderCalls.add((oldIndex, newIndex));
      },
      gapBehavior: (_) => FrameLeanReorderGapBehavior.restoreOrigin,
      onDrop: (_) => FrameLeanReorderDropDisposition.cancelled,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('handle-a'))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(const Offset(500, 200));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(reorderCalls, isEmpty);
    expect(
      tester.getTopLeft(find.text('A')).dy,
      lessThan(tester.getTopLeft(find.text('B')).dy),
    );
  });
}

Future<void> _pumpList(
  WidgetTester tester, {
  required void Function(int oldIndex, int newIndex) onReorder,
  void Function(FrameLeanReorderGapDetails details)? onReorderUpdate,
  FrameLeanReorderGapBehavior Function(FrameLeanReorderGapDetails details)?
  gapBehavior,
  FrameLeanReorderDropDisposition Function(FrameLeanReorderDropDetails details)?
  onDrop,
}) async {
  const items = ['A', 'B', 'C'];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 260,
            height: 240,
            child: FrameLeanReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: items.length,
              onReorder: onReorder,
              onReorderUpdate: onReorderUpdate,
              gapBehavior: gapBehavior,
              onDrop: onDrop,
              itemBuilder: (context, index) {
                return _TestItem(
                  key: ValueKey(items[index]),
                  label: items[index],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

class _TestItem extends StatelessWidget {
  const _TestItem({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          FrameLeanReorderableDragStartListener(
            key: Key('handle-${label.toLowerCase()}'),
            index: switch (label) {
              'A' => 0,
              'B' => 1,
              _ => 2,
            },
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(Icons.drag_indicator),
            ),
          ),
          Text(label),
        ],
      ),
    );
  }
}
