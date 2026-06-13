import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/app/theme/framelean_responsive.dart';

void main() {
  testWidgets('desktop font scale grows on large displays with an upper cap', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1370, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    double? resolvedFontSize;

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: frameLeanScreenDesignSize,
        minTextAdapt: true,
        splitScreenMode: true,
        fontSizeResolver: frameLeanFontSizeResolver,
        builder: (context, child) {
          resolvedFontSize = 14.flSp;
          return const SizedBox.shrink();
        },
      ),
    );

    expect(resolvedFontSize, closeTo(14 * 1.24, 0.001));
  });

  testWidgets('desktop font scale can shrink in compact windows', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(500, 420);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    double? resolvedFontSize;

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: frameLeanScreenDesignSize,
        minTextAdapt: true,
        splitScreenMode: true,
        fontSizeResolver: frameLeanFontSizeResolver,
        builder: (context, child) {
          resolvedFontSize = 14.flSp;
          return const SizedBox.shrink();
        },
      ),
    );

    expect(resolvedFontSize, lessThan(14));
  });
}
