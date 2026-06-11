import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/services/app_maintenance/app_cache_cleaner.dart';
import 'package:framelean/application/services/app_settings/app_settings_save_target.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/enums/app_theme_mode.dart';
import 'package:framelean/domain/enums/default_output_file_name_template.dart';
import 'package:framelean/domain/enums/media_output_format.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/audio_processing_config.dart';
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
    expect(find.text('关闭通知角标'), findsOneWidget);
    expect(find.text('跟随系统'), findsOneWidget);
    expect(find.text('不通知'), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
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
    await tester.tap(find.text('关闭通知角标'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(savedSettings, isNotNull);
    expect(savedSettings!.themeMode, AppThemeMode.dark);
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
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(savedSettings, isNull);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
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

  testWidgets('saves output directory and file name template', (tester) async {
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
    await tester.tap(find.text('保存到原文件旁'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byType(DropdownButtonFormField<DefaultOutputFileNameTemplate>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('源文件名-日期-压缩编码格式').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(savedSettings, isNotNull);
    expect(savedSettings!.saveOutputToSourceDirectory, isFalse);
    expect(savedSettings!.defaultOutputDirectory, '/tmp/framelean-picked');
    expect(
      savedSettings!.defaultOutputFileNameTemplate,
      DefaultOutputFileNameTemplate.sourceFileNameDateCodec,
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
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final video = savedSettings!.defaultMediaConfig.video;
    expect(savedSettings, isNotNull);
    expect(video?.smartPreset, SmartCompressionPreset.clear);
    expect(video?.videoCodec, VideoCodec.hevc);
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
    await tester.tap(
      find.byType(DropdownButtonFormField<MediaOutputFormat>).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('PNG').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '82');
    await tester.pumpAndSettle();
    await tester.tap(find.text('保留图片元数据'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final image = savedSettings!.defaultMediaConfig.image;
    expect(savedSettings, isNotNull);
    expect(image?.outputFormat, MediaOutputFormat.png);
    expect(image?.imageQuality, 82);
    expect(image?.preserveMetadata, isTrue);
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
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final audio = savedSettings!.defaultMediaConfig.audio;
    expect(savedSettings, isNotNull);
    expect(audio?.bitratePreset, AudioBitratePreset.k128);
    expect(audio?.channels, AudioChannelsPreset.mono);
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
