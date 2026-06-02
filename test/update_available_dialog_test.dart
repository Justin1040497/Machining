import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/services/update/app_update_checker.dart';
import 'package:framelean/application/services/update/app_version.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/update_available_dialog.dart';

void main() {
  testWidgets('update dialog shows versions and release notes', (tester) async {
    var closeTapped = false;
    var openReleasePageTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UpdateAvailableDialog(
            currentVersionLabel: '1.1.5',
            release: AppUpdateRelease(
              version: AppVersion.parse('1.1.6'),
              title: 'FrameLean v1.1.6',
              releaseNotes: '## 更新内容\n- 新增检查更新',
              releasePageUrl: Uri.parse(
                'https://framelean.example.com/releases/v1.1.6',
              ),
              packageAsset: AppUpdateAsset(
                name: 'FrameLean-v1.1.6.dmg',
                downloadUrl: Uri.parse(
                  'https://downloads.example.com/releases/v1.1.6/FrameLean-v1.1.6.dmg',
                ),
                sizeBytes: 123,
              ),
            ),
            onClose: () {
              closeTapped = true;
            },
            onOpenReleasePage: () {
              openReleasePageTapped = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('当前版本'), findsOneWidget);
    expect(find.text('1.1.5'), findsOneWidget);
    expect(find.text('最新版本'), findsOneWidget);
    expect(find.text('1.1.6'), findsOneWidget);
    expect(find.textContaining('新增检查更新'), findsOneWidget);

    await tester.tap(find.text('稍后'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('打开发布页'));
    await tester.pumpAndSettle();

    expect(closeTapped, isTrue);
    expect(openReleasePageTapped, isTrue);
  });
}
