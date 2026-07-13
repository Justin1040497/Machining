import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/features/workbench/guide/arrow/doodle_arrow.dart';
import 'package:framelean/features/workbench/guide/arrow/doodle_arrow_geometry.dart';
import 'package:framelean/features/workbench/guide/arrow/doodle_arrow_painter.dart';

void main() {
  test('doodle geometry keeps control points moving toward the target', () {
    final geometry = DoodleArrowGeometry.create(
      startPoint: Offset.zero,
      targetPoint: const Offset(240, 0),
      curveSeed: 42,
    );

    expect(geometry.controlPoint1.dx, greaterThan(0));
    expect(geometry.controlPoint2.dx, greaterThan(geometry.controlPoint1.dx));
    expect(geometry.controlPoint2.dx, lessThan(240));
    expect(geometry.controlPoint1.dy.abs(), lessThanOrEqualTo(32));
    expect(geometry.controlPoint2.dy.abs(), lessThanOrEqualTo(46));
    expect(geometry.body.computeMetrics().single.length, greaterThan(240));
  });

  testWidgets('moving an arrow target does not restart its draw animation', (
    tester,
  ) async {
    var target = const Offset(180, 80);
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 220,
          child: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return DoodleArrow(
                startPoint: const Offset(30, 150),
                targetPoint: target,
                color: Colors.grey,
                seed: 7,
              );
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    DoodleArrowPainter painter() {
      final customPaint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(DoodleArrow),
          matching: find.byType(CustomPaint),
        ),
      );
      return customPaint.painter! as DoodleArrowPainter;
    }

    expect(painter().progress, 1);
    target = const Offset(260, 60);
    rebuild(() {});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(painter().progress, 1);
    expect(painter().targetPoint.dx, inExclusiveRange(180, 260));

    await tester.pump(const Duration(milliseconds: 350));
    expect(painter().targetPoint, target);
  });
}
