import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/app_settings_dialog.dart';

void main() {
  testWidgets('settings dialog starts in compact source-directory state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkbenchAppSettingsDialog(
            initialSettings: AppSettings.initial().copyWith(
              defaultOutputDirectory: '/Users/leftzhou/Desktop',
            ),
            fallbackDefaultDirectory: '/Users/leftzhou/Desktop',
            onClose: () {},
            onSave: (_) async {},
            onPickOutputDirectory: () async => null,
            onPickFfmpegPath: () async => null,
            onPickFfprobePath: () async => null,
          ),
        ),
      ),
    );

    expect(find.text('应用设置'), findsOneWidget);
    expect(find.text('默认压缩配置'), findsOneWidget);
    expect(find.text('均衡方案'), findsOneWidget);
    expect(find.text('默认导出地址'), findsOneWidget);
    expect(find.text('/Users/leftzhou/Desktop'), findsOneWidget);
    expect(find.text('默认导出文件名'), findsOneWidget);
    expect(find.text('高级设置'), findsOneWidget);
    expect(find.text('检查更新'), findsNothing);
    expect(find.text('自定义FFmpeg路径'), findsNothing);
    expect(find.text('自定义FFprobe路径'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  });

  testWidgets('advanced button expands the same dialog vertically', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkbenchAppSettingsDialog(
            initialSettings: AppSettings.initial().copyWith(
              defaultOutputDirectory: '/Users/leftzhou/Desktop',
            ),
            fallbackDefaultDirectory: '/Users/leftzhou/Desktop',
            onClose: () {},
            onSave: (_) async {},
            onPickOutputDirectory: () async => null,
            onPickFfmpegPath: () async => null,
            onPickFfprobePath: () async => null,
          ),
        ),
      ),
    );

    await tester.tap(find.text('高级设置'));
    await tester.pumpAndSettle();

    expect(find.text('自定义FFmpeg路径'), findsOneWidget);
    expect(find.text('自定义FFprobe路径'), findsOneWidget);
    expect(find.text('为空则默认使用内置编码器'), findsOneWidget);
    expect(find.text('为空则默认使用内置分析器'), findsOneWidget);
    expect(find.text('高级设置'), findsNothing);
    expect(find.text('关闭高级选项'), findsOneWidget);
    expect(find.text('检查更新'), findsNothing);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);

    await tester.tap(find.text('关闭高级选项'));
    await tester.pumpAndSettle();

    expect(find.text('高级设置'), findsOneWidget);
    expect(find.text('检查更新'), findsNothing);
    expect(find.text('自定义FFmpeg路径'), findsNothing);
    expect(find.text('自定义FFprobe路径'), findsNothing);
  });

  testWidgets(
    'custom output path is enabled only when source directory is off',
    (tester) async {
      AppSettings? savedSettings;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkbenchAppSettingsDialog(
              initialSettings: AppSettings.initial(),
              fallbackDefaultDirectory: '/Users/leftzhou/Desktop',
              onClose: () {},
              onSave: (settings) async {
                savedSettings = settings;
              },
              onPickOutputDirectory: () async => '/tmp/output',
              onPickFfmpegPath: () async => null,
              onPickFfprobePath: () async => null,
            ),
          ),
        ),
      );

      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);

      await tester.tap(find.byTooltip('选择路径'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('均衡方案'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('微信发送').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(savedSettings, isNotNull);
      expect(savedSettings!.saveOutputToSourceDirectory, isFalse);
      expect(savedSettings!.defaultOutputDirectory, '/tmp/output');
      expect(savedSettings!.defaultSmartPreset, SmartCompressionPreset.chat);
    },
  );
}
