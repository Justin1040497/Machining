import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/workbench_about_dialog.dart';

void main() {
  testWidgets('about dialog shows app info and repository actions', (
    tester,
  ) async {
    var githubTapped = false;
    var giteeTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkbenchAboutDialog(
            onClose: () {},
            onOpenGitHub: () {
              githubTapped = true;
            },
            onOpenGitee: () {
              giteeTapped = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('关于'), findsOneWidget);
    expect(find.textContaining('桌面媒体处理工具'), findsOneWidget);
    expect(find.text('当前版本：1.1.5'), findsOneWidget);
    expect(find.text('关闭'), findsOneWidget);
    expect(find.byTooltip('打开 GitHub'), findsOneWidget);
    expect(find.byTooltip('打开 Gitee'), findsOneWidget);

    await tester.tap(find.byTooltip('打开 GitHub'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('打开 Gitee'));
    await tester.pumpAndSettle();

    expect(githubTapped, isTrue);
    expect(giteeTapped, isTrue);
  });
}
