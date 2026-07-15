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
      maxLength: 280,
      curveBias: Offset.zero,
    );

    expect(geometry.controlPoint1.dx, greaterThan(0));
    expect(geometry.controlPoint2.dx, greaterThan(geometry.controlPoint1.dx));
    expect(geometry.middlePoint.dx, greaterThan(geometry.controlPoint2.dx));
    expect(geometry.controlPoint3.dx, greaterThan(geometry.middlePoint.dx));
    expect(geometry.controlPoint4.dx, greaterThan(geometry.controlPoint3.dx));
    expect(geometry.controlPoint4.dx, lessThan(240));
    expect(geometry.controlPoint1.dy.abs(), lessThanOrEqualTo(32));
    expect(geometry.controlPoint2.dy.abs(), lessThanOrEqualTo(46));
    expect(geometry.middlePoint.dy.abs(), greaterThan(10));
    expect(geometry.controlPoint4.dy.sign, -geometry.middlePoint.dy.sign);
    expect(geometry.body.computeMetrics().single.length, greaterThan(240));
  });

  test('doodle arrowhead is closed, hatched, emphasized, and size bounded', () {
    final head = DoodleArrowGeometry.createArrowHead(
      tip: const Offset(240, 80),
      direction: const Offset(1, -0.2),
      bodyLength: 260,
      scale: 1,
      curveSeed: 42,
    );

    final outlineMetric = head.outline.computeMetrics().single;
    expect(outlineMetric.isClosed, isTrue);
    expect(head.length, inInclusiveRange(22, 30));
    expect(head.hatching.computeMetrics().length, 3);
    expect(head.emphasis.computeMetrics().length, 3);
    expect(head.outline.getBounds().width, greaterThan(25));
    expect(head.baseNotch.dx, lessThan(240));
    expect(head.direction.distance, closeTo(1, 0.001));
    expect(head.direction.dx, greaterThan(0));
  });

  test('doodle geometry honors the requested target direction', () {
    final geometry = DoodleArrowGeometry.create(
      startPoint: const Offset(40, 160),
      targetPoint: const Offset(260, 80),
      targetDirection: const Offset(0, -1),
      curveSeed: 9,
      maxLength: 280,
      curveBias: const Offset(0, 20),
    );

    final finalTangent = geometry.target - geometry.controlPoint4;
    expect(finalTangent.dx.abs(), lessThan(0.001));
    expect(finalTangent.dy, lessThan(0));
  });

  test('task route forms a deep bowl before entering upward', () {
    final geometry = DoodleArrowGeometry.create(
      startPoint: const Offset(0, 40),
      targetPoint: const Offset(200, 0),
      targetDirection: const Offset(0, -1),
      curveSeed: 1401,
      maxLength: 245,
      curveBias: const Offset(0, 72),
    );

    expect(geometry.middlePoint.dy, greaterThan(80));
    expect(geometry.controlPoint4.dx, closeTo(200, 0.001));
    expect(geometry.controlPoint4.dy, greaterThan(geometry.target.dy));
  });

  test('start-all route arches upward before entering downward', () {
    final geometry = DoodleArrowGeometry.create(
      startPoint: const Offset(200, 0),
      targetPoint: const Offset(0, 80),
      targetDirection: const Offset(0, 1),
      curveSeed: 2803,
      maxLength: 245,
      curveBias: const Offset(0, -72),
    );

    expect(geometry.middlePoint.dy, lessThan(-10));
    expect(geometry.controlPoint4.dx, closeTo(0, 0.001));
    expect(geometry.controlPoint4.dy, lessThan(geometry.target.dy));
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
