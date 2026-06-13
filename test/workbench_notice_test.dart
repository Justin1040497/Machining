import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:framelean/app/theme/framelean_responsive.dart';
import 'package:framelean/app/theme/framelean_theme.dart';
import 'package:framelean/domain/enums/app_notification_level.dart';
import 'package:framelean/features/workbench/pages/workbench_page/overlays/workbench_notice.dart';

void main() {
  testWidgets('success notice uses balanced desktop dimensions', (
    tester,
  ) async {
    await pumpNotice(
      tester,
      title: '应用主题已保存',
      level: AppNotificationLevel.success,
    );

    final cardSize = tester.getSize(
      find.byKey(const ValueKey('app-notification-card')),
    );
    final cardPosition = tester.getTopLeft(
      find.byKey(const ValueKey('app-notification-card')),
    );
    final cardRect = tester.getRect(
      find.byKey(const ValueKey('app-notification-card')),
    );
    final closeButtonRect = tester.getRect(
      find.byKey(const ValueKey('app-notification-close-button')),
    );
    expect(cardSize.width, inInclusiveRange(260, 270));
    expect(cardSize.height, inInclusiveRange(52, 60));
    expect(cardPosition.dy, lessThanOrEqualTo(58));
    expect(cardRect.right - closeButtonRect.right, lessThanOrEqualTo(8));
    expect(tester.takeException(), isNull);
  });

  testWidgets('error notice keeps two readable detail lines', (tester) async {
    const detail = '输出配置已保存，非运行状态的任务已更新；正在处理的任务将在下次处理时使用新配置';
    await pumpNotice(
      tester,
      title: '输出配置已保存',
      message: detail,
      level: AppNotificationLevel.success,
    );

    expect(find.text('输出配置已保存'), findsOneWidget);
    expect(find.text(detail), findsOneWidget);
    final detailText = tester.widget<Text>(find.text(detail));
    expect(detailText.maxLines, 2);
    final cardSize = tester.getSize(
      find.byKey(const ValueKey('app-notification-card')),
    );
    expect(cardSize.width, 300);
    expect(cardSize.height, inInclusiveRange(70, 84));
    expect(tester.takeException(), isNull);
  });
}

Future<void> pumpNotice(
  WidgetTester tester, {
  required String title,
  String message = '',
  required AppNotificationLevel level,
}) async {
  final visible = ValueNotifier(true);
  addTearDown(visible.dispose);

  await tester.pumpWidget(
    ScreenUtilInit(
      designSize: frameLeanScreenDesignSize,
      fontSizeResolver: frameLeanFontSizeResolver,
      builder: (context, child) {
        return MaterialApp(
          theme: frameLeanLightTheme(),
          home: Scaffold(
            body: Stack(
              children: [
                WorkbenchNotice(
                  title: title,
                  message: message,
                  level: level,
                  visibleListenable: visible,
                  onDismissed: () {},
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  await tester.pump(const Duration(milliseconds: 250));
}
