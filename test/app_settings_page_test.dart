import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/services/app_maintenance/app_cache_cleaner.dart';
import 'package:framelean/application/services/app_settings/app_settings_save_target.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/enums/app_theme_mode.dart';
import 'package:framelean/domain/enums/media_output_format.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/task_completion_sound.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/audio_processing_config.dart';
import 'package:framelean/domain/value_objects/app_update_state.dart';
import 'package:framelean/features/settings/pages/app_settings_page.dart';

void main() {
  testWidgets('settings page matches prototype navigation', (tester) async {
    await pumpSettingsPage(tester);

    expect(find.text('返回工作台'), findsOneWidget);
    expect(find.text('常规配置'), findsOneWidget);
    expect(find.text('任务设置'), findsOneWidget);
    expect(find.text('输入和输出'), findsOneWidget);
    expect(find.text('应用设置'), findsWidgets);
    expect(find.text('关于'), findsOneWidget);
    expect(find.text('视频任务'), findsOneWidget);
    expect(find.text('图片任务'), findsOneWidget);
    expect(find.text('音频任务'), findsOneWidget);
    expect(find.text('输出配置'), findsOneWidget);
    expect(find.text('编码器配置'), findsOneWidget);
    expect(find.text('应用主题颜色'), findsOneWidget);
    expect(find.text('完成音频设置'), findsOneWidget);
    expect(find.text('任务完成后以弹窗的形式提示'), findsNothing);
    expect(find.text('关闭通知角标'), findsOneWidget);
    expect(find.text('跟随系统'), findsOneWidget);
    expect(find.text('清脆完成'), findsOneWidget);
    expect(
      tester
          .widgetList<Checkbox>(find.byType(Checkbox))
          .map((widget) => widget.value),
      everyElement(isTrue),
    );
  });

  testWidgets('saves app preferences from app settings section', (
    tester,
  ) async {
    AppSettings? savedSettings;
    AppSettingsSaveTarget? savedTarget;

    await pumpSettingsPage(
      tester,
      onSaveWithTarget: (settings, target) async {
        savedSettings = settings;
        savedTarget = target;
      },
    );

    await tester.tap(find.byType(DropdownButtonFormField<AppThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<TaskCompletionSound>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('柔云提示').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭通知角标'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(savedSettings, isNotNull);
    expect(savedSettings!.themeMode, AppThemeMode.dark);
    expect(
      savedSettings!.taskCompletionSound,
      TaskCompletionSound.originalSoftA,
    );
    expect(savedSettings!.hideNotificationBadge, isFalse);
    expect(savedTarget, AppSettingsSaveTarget.application);
  });

  testWidgets('cancel restores notification badge preference', (tester) async {
    AppSettings? savedSettings;

    await pumpSettingsPage(
      tester,
      onSave: (settings) async => savedSettings = settings,
    );

    await tester.tap(find.text('关闭通知角标'));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox).last).value, isFalse);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(savedSettings, isNull);
    expect(tester.widget<Checkbox>(find.byType(Checkbox).last).value, isTrue);
  });

  testWidgets('switching sections reverts unsaved edits without saving', (
    tester,
  ) async {
    AppSettings? savedSettings;

    await pumpSettingsPage(
      tester,
      onSave: (settings) async => savedSettings = settings,
    );

    await tester.tap(find.byType(DropdownButtonFormField<AppThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色').last);
    await tester.pumpAndSettle();
    expect(find.text('深色'), findsOneWidget);

    await tester.tap(find.text('视频任务'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('应用设置').first);
    await tester.pumpAndSettle();

    expect(savedSettings, isNull);
    expect(find.text('跟随系统'), findsOneWidget);
  });

  testWidgets('cancel reverts current section without saving', (tester) async {
    AppSettings? savedSettings;

    await pumpSettingsPage(
      tester,
      onSave: (settings) async => savedSettings = settings,
    );

    await tester.tap(find.byType(DropdownButtonFormField<AppThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(savedSettings, isNull);
    expect(find.text('跟随系统'), findsOneWidget);
  });

  testWidgets('leaving settings reverts current section without saving', (
    tester,
  ) async {
    AppSettings? savedSettings;
    var closed = false;

    await pumpSettingsPage(
      tester,
      onSave: (settings) async => savedSettings = settings,
      onClose: () {
        closed = true;
      },
    );

    await tester.tap(find.byType(DropdownButtonFormField<AppThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('返回工作台'));
    await tester.pumpAndSettle();

    expect(savedSettings, isNull);
    expect(closed, isTrue);
  });

  testWidgets('failed save keeps edits dirty for retry or cancel', (
    tester,
  ) async {
    AppSettings? savedSettings;

    await pumpSettingsPage(
      tester,
      onSave: (settings) async {
        savedSettings = settings;
        throw StateError('无法保存设置');
      },
    );

    await tester.tap(find.byType(DropdownButtonFormField<AppThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(savedSettings?.themeMode, AppThemeMode.dark);
    expect(find.text('深色'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('跟随系统'), findsOneWidget);
  });

  testWidgets('in-flight save can finish after settings view is unmounted', (
    tester,
  ) async {
    final saveCompleter = Completer<void>();
    AppSettings? savedSettings;

    await pumpSettingsPage(
      tester,
      onSave: (settings) async {
        await saveCompleter.future;
        savedSettings = settings;
      },
    );

    await tester.tap(find.byType(DropdownButtonFormField<AppThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深色').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    saveCompleter.complete();
    await tester.pump();

    expect(savedSettings?.themeMode, AppThemeMode.dark);
  });

  testWidgets('saves output directory and file name template text', (
    tester,
  ) async {
    AppSettings? savedSettings;

    await pumpSettingsPage(
      tester,
      initialSettings: AppSettings.initial().copyWith(
        saveOutputToSourceDirectory: true,
      ),
      onSave: (settings) async => savedSettings = settings,
    );

    await tester.tap(find.text('输出配置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存到源文件旁'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(SelectionArea), findsOneWidget);
    expect(find.textContaining('文件名模板用于生成默认导出名'), findsOneWidget);
    expect(find.textContaining('重复导出会优先递增为 v2、v3'), findsOneWidget);
    expect(find.text('source: 源文件名'), findsOneWidget);
    expect(find.text('date: 当前日期（yyyyMMdd）'), findsOneWidget);
    expect(find.text('version: 输出版本（v1 / v2 ...）'), findsOneWidget);
    expect(find.text('action: 任务类型（压缩 / 转换 / 处理）'), findsOneWidget);
    expect(find.text('codec: 编码格式（h264 / h265）'), findsOneWidget);
    expect(
      find.text('encoder: 视频编码器（x264 / x265 / videotoolbox 等）'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('选择常用模板'));
    await tester.pumpAndSettle();
    expect(find.text('源文件名 + 行为'), findsOneWidget);
    expect(find.text('{source}-{action}'), findsWidgets);
    expect(find.text('源文件名 + 时间 + 行为 + 版本'), findsOneWidget);
    expect(find.text('{source}-{date}-{action}-{version}'), findsOneWidget);
    expect(find.text('源文件名 + 编码格式'), findsOneWidget);
    expect(find.text('{source}-{codec}'), findsOneWidget);
    expect(find.text('源文件名 + 编码器'), findsOneWidget);
    expect(find.text('{source}-{encoder}'), findsOneWidget);
    expect(find.text('源文件名 + 时间'), findsOneWidget);
    expect(find.text('{source}-{date}'), findsOneWidget);
    await tester.tap(find.text('{source}-{codec}').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      '{source}-{codec}',
    );

    await tester.enterText(find.byType(TextField).last, '{source}-custom');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('选择常用模板'));
    await tester.pumpAndSettle();
    expect(find.text('{source}-{codec}'), findsOneWidget);
    await tester.tap(find.text('{source}-{codec}'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '{source}-custom');
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(savedSettings, isNotNull);
    expect(savedSettings!.saveOutputToSourceDirectory, isFalse);
    expect(savedSettings!.defaultOutputDirectory, '/tmp/framelean-picked');
    expect(savedSettings!.defaultOutputFileNameTemplate, '{source}-custom');
  });

  testWidgets('normalizes numeric x separators without changing x264', (
    tester,
  ) async {
    AppSettings? savedSettings;

    await pumpSettingsPage(
      tester,
      onSave: (settings) async => savedSettings = settings,
    );

    await tester.tap(find.text('输出配置'));
    await tester.pumpAndSettle();
    final templateField = find.byType(TextField).last;
    await tester.enterText(templateField, '{source}-1920x1080-x{encoder}-x264');
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(templateField).controller!.text,
      '{source}-1920×1080-{encoder}-x264',
    );

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(
      savedSettings!.defaultOutputFileNameTemplate,
      '{source}-1920×1080-{encoder}-x264',
    );
  });

  testWidgets('saves custom encoder paths', (tester) async {
    AppSettings? savedSettings;

    await pumpSettingsPage(
      tester,
      onSave: (settings) async => savedSettings = settings,
    );

    await tester.tap(find.text('编码器配置'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz_rounded).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(savedSettings, isNotNull);
    expect(savedSettings!.customFfmpegPath, '/usr/local/bin/ffmpeg');
    expect(savedSettings!.customFfprobePath, '/usr/local/bin/ffprobe');
  });

  testWidgets('saves video defaults', (tester) async {
    AppSettings? savedSettings;

    await pumpSettingsPage(
      tester,
      onSave: (settings) async => savedSettings = settings,
    );

    await tester.tap(find.text('视频任务'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byType(DropdownButtonFormField<SmartCompressionPreset>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('清晰优先').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<VideoCodec>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('H.265 / HEVC').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保留视频元数据'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final video = savedSettings!.defaultMediaConfig.video;
    expect(savedSettings, isNotNull);
    expect(video?.smartPreset, SmartCompressionPreset.clear);
    expect(video?.videoCodec, VideoCodec.hevc);
    expect(video?.preserveMetadata, isFalse);
    expect(savedSettings!.defaultOutputVideoCodec, VideoCodec.hevc);
    expect(savedSettings!.defaultSmartPreset, SmartCompressionPreset.clear);
  });

  testWidgets('saves image defaults', (tester) async {
    AppSettings? savedSettings;

    await pumpSettingsPage(
      tester,
      onSave: (settings) async => savedSettings = settings,
    );

    await tester.tap(find.text('图片任务'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('默认保持源文件图片格式'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byType(DropdownButtonFormField<MediaOutputFormat>).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('PNG').last);
    await tester.pumpAndSettle();
    tester.widget<Slider>(find.byType(Slider)).onChanged!(7);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保留图片元数据'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final image = savedSettings!.defaultMediaConfig.image;
    expect(savedSettings, isNotNull);
    expect(image?.outputFormat, MediaOutputFormat.png);
    expect(image?.imageQuality, 80);
    expect(image?.preserveMetadata, isFalse);
  });

  testWidgets('saves audio defaults', (tester) async {
    AppSettings? savedSettings;

    await pumpSettingsPage(
      tester,
      onSave: (settings) async => savedSettings = settings,
    );

    await tester.tap(find.text('音频任务'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<AudioBitratePreset>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('128 kbps').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<AudioChannelsPreset>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('单声道').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保留音频元数据'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final audio = savedSettings!.defaultMediaConfig.audio;
    expect(savedSettings, isNotNull);
    expect(audio?.bitratePreset, AudioBitratePreset.k128);
    expect(audio?.channels, AudioChannelsPreset.mono);
    expect(audio?.preserveMetadata, isFalse);
  });

  testWidgets('about section shows version and cache cleanup action', (
    tester,
  ) async {
    await pumpSettingsPage(
      tester,
      onPreviewAppCacheCleanup: () async => const AppCacheCleanupPreview(
        fileCount: 0,
        directoryCount: 0,
        totalBytes: 0,
        targetPaths: [],
        missingTargetPaths: [],
      ),
    );

    await tester.tap(find.text('关于'));
    await tester.pumpAndSettle();

    expect(find.text('项目简介'), findsOneWidget);
    expect(find.textContaining('当前版本：'), findsOneWidget);
    expect(find.text('清空应用缓存'), findsOneWidget);

    await tester.tap(find.text('清空应用缓存'));
    await tester.pumpAndSettle();

    expect(find.text('应用缓存为空'), findsOneWidget);
  });

  testWidgets('about section opens social links', (tester) async {
    final openedLinks = <String>[];

    await pumpSettingsPage(
      tester,
      onOpenExternalLink: (url) async {
        openedLinks.add(url);
      },
    );

    await tester.tap(find.text('关于'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Gitee'));
    await tester.tap(find.byTooltip('GitHub'));
    await tester.tap(find.byTooltip('Gmail'));
    await tester.tap(find.byTooltip('掘金'));
    await tester.pumpAndSettle();

    expect(openedLinks, [
      'https://gitee.com/zhouycheng/FrameLean',
      'https://github.com/zhouycheng/FrameLean',
      'mailto:justinzhouself@gmail.com',
      'https://juejin.cn/user/394062317754227',
    ]);
  });
}

Future<void> pumpSettingsPage(
  WidgetTester tester, {
  AppSettings? initialSettings,
  Future<void> Function(AppSettings settings)? onSave,
  Future<void> Function(AppSettings settings, AppSettingsSaveTarget target)?
  onSaveWithTarget,
  VoidCallback? onClose,
  AppCacheCleanupPreviewCallback? onPreviewAppCacheCleanup,
  AppSettingsExternalLinkCallback? onOpenExternalLink,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AppSettingsView(
          initialSettings: initialSettings ?? AppSettings.initial(),
          fallbackDefaultDirectory: '/tmp/framelean-output',
          updateState: AppUpdateState.initial(),
          onSave: (settings, target) {
            final scopedCallback = onSaveWithTarget;
            if (scopedCallback != null) {
              return scopedCallback(settings, target);
            }
            return (onSave ?? (_) async {})(settings);
          },
          onPickOutputDirectory: () async => '/tmp/framelean-picked',
          onPickFfmpegPath: () async => '/usr/local/bin/ffmpeg',
          onPickFfprobePath: () async => '/usr/local/bin/ffprobe',
          onClose: onClose,
          onPreviewAppCacheCleanup:
              onPreviewAppCacheCleanup ??
              () async => const AppCacheCleanupPreview(
                fileCount: 1,
                directoryCount: 1,
                totalBytes: 2048,
                targetPaths: ['/tmp/framelean/previews'],
                missingTargetPaths: [],
              ),
          onClearAppCache: () async => const AppCacheCleanupResult(
            deletedFileCount: 1,
            deletedDirectoryCount: 1,
            releasedBytes: 2048,
            skippedItems: [],
          ),
          onOpenExternalLink: onOpenExternalLink,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
