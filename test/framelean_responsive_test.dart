import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/app/theme/framelean_responsive.dart';

void main() {
  testWidgets('desktop font scale does not grow past the base size', (
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

    expect(resolvedFontSize, 14);
  });
}
