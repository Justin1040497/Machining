import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/workbench_about_dialog.dart';

void main() {
  testWidgets('about dialog shows app info and update actions', (tester) async {
    var checkUpdateTapped = false;
    var githubTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkbenchAboutDialog(
            onClose: () {},
            onCheckUpdate: () {
              checkUpdateTapped = true;
            },
            onOpenGitHub: () {
              githubTapped = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('关于'), findsOneWidget);
    expect(find.textContaining('桌面视频压缩工具'), findsOneWidget);
    expect(find.text('当前版本：1.1.5'), findsOneWidget);
    expect(find.text('检查更新'), findsOneWidget);
    expect(find.text('关闭'), findsOneWidget);
    expect(find.byTooltip('打开 GitHub'), findsOneWidget);

    await tester.tap(find.text('检查更新'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('打开 GitHub'));
    await tester.pumpAndSettle();

    expect(checkUpdateTapped, isTrue);
    expect(githubTapped, isTrue);
  });
}
