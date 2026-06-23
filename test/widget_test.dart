import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/app/constants.dart';
import 'package:framelean/app/presentation/widgets/reorderable/framelean_reorderable_list_view.dart';
import 'package:framelean/app/theme/framelean_colors.dart';
import 'package:framelean/app/theme/framelean_theme.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/app_theme_mode.dart';
import 'package:framelean/domain/enums/compression_mode.dart';
import 'package:framelean/domain/enums/encoder_backend.dart';
import 'package:framelean/domain/enums/hdr_output_mode.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/media_output_format.dart';
import 'package:framelean/domain/enums/output_format.dart';
import 'package:framelean/domain/enums/resolution_preset.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/two_pass_mode.dart';
import 'package:framelean/domain/enums/output_location_mode.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/audio_processing_config.dart';
import 'package:framelean/domain/value_objects/image_processing_config.dart';
import 'package:framelean/domain/value_objects/media_analysis_result.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/domain/value_objects/source_file_fingerprint.dart';
import 'package:framelean/domain/value_objects/video_processing_config.dart';
import 'package:framelean/domain/value_objects/video_output_compatibility.dart';
import 'package:framelean/domain/value_objects/video_task_config.dart';
import 'package:framelean/app/presentation/widgets/confirm_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task/task_config_dialog_template.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task/task_configuration_dialog_widgets.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/config/video_config_panel.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/config/image_config_panel.dart';
import 'package:framelean/app/presentation/widgets/app_dialog_frame.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/config/audio_config_panel.dart';
import 'package:framelean/features/workbench/pages/workbench_page/layout/workbench_shell.dart';
import 'package:framelean/features/workbench/pages/workbench_page/layout/top_bar.dart';
import 'package:framelean/app/presentation/widgets/form_controls/config_dropdown.dart';
import 'package:framelean/app/presentation/widgets/form_controls/config_checkbox.dart';
import 'package:framelean/app/presentation/domain_labels.dart';
import 'package:framelean/features/workbench/widgets/media_task_list/media_task_list_tile.dart';
import 'package:framelean/features/workbench/widgets/media_task_list/task_folder_content_panel.dart';
import 'package:framelean/features/workbench/widgets/media_task_list/task_folder_list_tile.dart';
import 'package:framelean/domain/entities/task_folder.dart';

void main() {
  testWidgets('recommended presets do not change resolution automatically', (
    tester,
  ) async {
    final resolutionChanges = <ResolutionPreset>[];
    final smartPresetChanges = <SmartCompressionPreset>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _TestTaskConfigDialog(
            task: testTask(),
            thumbnail: null,
            selectedQualityIndex: 4,
            selectedOutputFormat: OutputFormat.mp4,
            selectedVideoCodec: VideoCodec.h264,
            selectedEncoderBackend: EncoderBackend.auto,
            selectedResolutionPreset: ResolutionPreset.original,
            selectedCompressionMode: CompressionMode.preset,
            selectedSmartPreset: SmartCompressionPreset.balanced,
            selectedTargetSizeRatio: 0.6,
            availableEncoderBackends: const [EncoderBackend.auto],
            onClose: () {},
            onOpenSource: () {},
            onSave: () {},
            onCompressionModeChanged: (_) {},
            onSmartPresetChanged: smartPresetChanges.add,
            onTargetSizeRatioChanged: (_) {},
            onQualityChanged: (_) {},
            onOutputFormatChanged: (_) {},
            onVideoCodecChanged: (_) {},
            onEncoderBackendChanged: (_) {},
            onResolutionPresetChanged: resolutionChanges.add,
          ),
        ),
      ),
    );

    await tester.tap(find.text('微信发送'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('体积优先'));
    await tester.pumpAndSettle();

    expect(smartPresetChanges, [
      SmartCompressionPreset.chat,
      SmartCompressionPreset.compact,
    ]);
    expect(resolutionChanges, isEmpty);
  });

  testWidgets('preserve HDR disables target size and risky presets', (
    tester,
  ) async {
    final modeChanges = <CompressionMode>[];
    final smartPresetChanges = <SmartCompressionPreset>[];
    final preserveHdrChanges = <bool>[];
    final metadataChanges = <bool>[];
    final videoConfig = VideoProcessingConfig.initial().copyWith(
      videoCodec: VideoCodec.hevc,
      hdrOutputMode: HdrOutputMode.preserveHdr,
      smartPreset: SmartCompressionPreset.clear,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _TestTaskConfigDialog(
            task: MediaTask(
              id: 'task-hdr',
              inputPath: '/videos/hdr.mov',
              fileName: 'hdr.mov',
              mediaKind: MediaKind.video,
              purpose: TaskPurpose.compression,
              status: TaskStatus.pending,
              config: MediaTaskConfig.initialVideo().copyWith(
                video: videoConfig,
              ),
              progress: 0,
              sortOrder: 0,
              createdAt: 1,
              sourceFileFingerprint: const SourceFileFingerprint(
                fileSize: 100 * 1024 * 1024,
                lastModifiedAt: 1,
              ),
              analysisResult: MediaAnalysisResult(
                durationMs: 60000,
                videoWidth: 3840,
                videoHeight: 2160,
                videoCodec: 'hevc',
                videoBitrate: 12000000,
                videoBitDepth: 10,
                colorSpace: 'bt2020nc',
                colorTransfer: 'smpte2084',
                colorPrimaries: 'bt2020',
              ),
            ),
            thumbnail: null,
            selectedQualityIndex: 3,
            selectedOutputFormat: OutputFormat.mov,
            selectedVideoCodec: VideoCodec.hevc,
            selectedEncoderBackend: EncoderBackend.auto,
            selectedResolutionPreset: ResolutionPreset.original,
            selectedCompressionMode: CompressionMode.preset,
            selectedSmartPreset: SmartCompressionPreset.clear,
            selectedTargetSizeRatio: 0.6,
            selectedVideoConfig: videoConfig,
            availableEncoderBackends: const [EncoderBackend.auto],
            onClose: () {},
            onOpenSource: () {},
            onSave: () {},
            onCompressionModeChanged: modeChanges.add,
            onSmartPresetChanged: smartPresetChanges.add,
            onTargetSizeRatioChanged: (_) {},
            onQualityChanged: (_) {},
            onOutputFormatChanged: (_) {},
            onVideoCodecChanged: (_) {},
            onEncoderBackendChanged: (_) {},
            onResolutionPresetChanged: (_) {},
            onPreserveHdrChanged: preserveHdrChanges.add,
            onVideoPreserveMetadataChanged: metadataChanges.add,
          ),
        ),
      ),
    );

    final purposeControl = tester
        .widget<CupertinoSlidingSegmentedControl<TaskPurpose>>(
          find.byWidgetPredicate(
            (widget) => widget is CupertinoSlidingSegmentedControl<TaskPurpose>,
          ),
        );
    final compressionControl = tester
        .widget<CupertinoSlidingSegmentedControl<CompressionMode>>(
          find.byWidgetPredicate(
            (widget) =>
                widget is CupertinoSlidingSegmentedControl<CompressionMode>,
          ),
        );
    expect(purposeControl.groupValue, TaskPurpose.compression);
    expect(
      compressionControl.disabledChildren,
      contains(CompressionMode.targetSize),
    );
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(Checkbox), findsNWidgets(2));

    tester.widget<Checkbox>(find.byType(Checkbox).first).onChanged?.call(false);
    tester.widget<Checkbox>(find.byType(Checkbox).last).onChanged?.call(false);
    expect(preserveHdrChanges, [false]);
    expect(metadataChanges, [false]);

    await tester.tap(find.text('自定义目标体积'));
    await tester.pumpAndSettle();
    expect(modeChanges, isEmpty);
    expect(find.text('目标体积'), findsNothing);

    await tester.tap(find.text('微信发送'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('体积优先'));
    await tester.pumpAndSettle();
    expect(smartPresetChanges, isEmpty);

    await tester.tap(find.text('均衡推荐'));
    await tester.pumpAndSettle();
    expect(smartPresetChanges, [SmartCompressionPreset.balanced]);
  });

  testWidgets('source matching config does not mark preset modified', (
    tester,
  ) async {
    await _pumpTaskConfigurationDialog(tester);

    expect(find.text('已修改'), findsNothing);
    expect(find.text('修改'), findsNothing);
    expect(find.text('已调'), findsNothing);
  });

  testWidgets('matching explicit resolution does not mark preset modified', (
    tester,
  ) async {
    await _pumpTaskConfigurationDialog(
      tester,
      task: testTask(
        analysisResult: MediaAnalysisResult(
          durationMs: 60000,
          videoWidth: 1920,
          videoHeight: 1080,
          videoCodec: 'h264',
          videoBitrate: 8000000,
          audioBitrate: 128000,
        ),
      ),
      selectedResolutionPreset: ResolutionPreset.p1080,
    );

    expect(find.text('已修改'), findsNothing);
  });

  testWidgets('different resolution marks preset modified', (tester) async {
    await _pumpTaskConfigurationDialog(
      tester,
      selectedResolutionPreset: ResolutionPreset.p1080,
    );

    expect(find.text('已修改'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppDialogActions),
        matching: find.text('已修改'),
      ),
      findsOneWidget,
    );
    expect(find.text('修改'), findsNothing);
  });

  testWidgets('different video codec marks preset modified', (tester) async {
    await _pumpTaskConfigurationDialog(
      tester,
      selectedVideoCodec: VideoCodec.hevc,
    );

    expect(find.text('已修改'), findsOneWidget);
  });

  testWidgets('different output format marks preset modified', (tester) async {
    await _pumpTaskConfigurationDialog(
      tester,
      task: testTask(fileName: 'source.mov'),
      selectedOutputFormat: OutputFormat.mp4,
    );

    expect(find.text('已修改'), findsOneWidget);
  });

  testWidgets('video source format option shows keep original label', (
    tester,
  ) async {
    await _pumpTaskConfigurationDialog(
      tester,
      task: testTask(fileName: 'source.mov'),
      selectedOutputFormat: OutputFormat.mp4,
    );

    await tester.tap(find.byType(DropdownButtonFormField<OutputFormat>));
    await tester.pumpAndSettle();

    expect(find.text('MOV（保持原始）'), findsOneWidget);
  });

  test(
    'non-video task configuration initial values do not require video config',
    () {
      final imageValues = resolveWorkbenchTaskConfigurationInitialValues(
        task: imageTask(),
        selectedQualityIndex: 5,
        selectedOutputFormat: OutputFormat.mkv,
        selectedVideoCodec: VideoCodec.hevc,
        selectedEncoderBackend: EncoderBackend.videotoolbox,
        selectedResolutionPreset: ResolutionPreset.p720,
        selectedSmartPreset: SmartCompressionPreset.clear,
      );
      final audioValues = resolveWorkbenchTaskConfigurationInitialValues(
        task: audioTask(),
        selectedQualityIndex: 5,
        selectedOutputFormat: OutputFormat.mkv,
        selectedVideoCodec: VideoCodec.hevc,
        selectedEncoderBackend: EncoderBackend.videotoolbox,
        selectedResolutionPreset: ResolutionPreset.p720,
        selectedSmartPreset: SmartCompressionPreset.clear,
      );

      expect(imageValues.outputFormat, OutputFormat.mkv);
      expect(audioValues.outputFormat, OutputFormat.mkv);
      expect(imageValues.encoderBackend, EncoderBackend.videotoolbox);
      expect(audioValues.encoderBackend, EncoderBackend.videotoolbox);
    },
  );

  test('opened task folder list is mutable when no folder is open', () {
    final folderTasks = resolveOpenedTaskFolderTasks(
      tasks: const [],
      openedFolder: null,
    );

    expect(folderTasks, isEmpty);
    expect(() => folderTasks.add(testTask()), returnsNormally);
  });

  test(
    'opened task folder list only includes folder children in folder order',
    () {
      final folder = TaskFolder(
        id: 'folder-1',
        name: '视频任务夹（1）',
        mediaKind: MediaKind.video,
        sortOrder: 0,
        defaultConfig: MediaTaskConfig.initialVideo(),
        createdAt: 1,
        updatedAt: 1,
      );
      final laterTask = testTask(
        fileName: 'later.mp4',
      ).copyWith(id: 'later', folderId: folder.id, folderSortOrder: 2);
      final earlierTask = testTask(
        fileName: 'earlier.mp4',
      ).copyWith(id: 'earlier', folderId: folder.id, folderSortOrder: 1);
      final looseTask = testTask(fileName: 'loose.mp4').copyWith(id: 'loose');

      final folderTasks = resolveOpenedTaskFolderTasks(
        tasks: [laterTask, looseTask, earlierTask],
        openedFolder: folder,
      );

      expect(folderTasks.map((task) => task.id), ['earlier', 'later']);
    },
  );

  testWidgets('target size mode uses segmented ratio slider', (tester) async {
    final ratioChanges = <double>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _TestTaskConfigDialog(
            task: testTask(
              config: VideoTaskConfig.initial().copyWith(
                compressionMode: CompressionMode.targetSize,
                targetSizeRatio: 0.6,
              ),
            ),
            thumbnail: null,
            selectedQualityIndex: 3,
            selectedOutputFormat: OutputFormat.mp4,
            selectedVideoCodec: VideoCodec.h264,
            selectedEncoderBackend: EncoderBackend.auto,
            selectedResolutionPreset: ResolutionPreset.original,
            selectedCompressionMode: CompressionMode.targetSize,
            selectedSmartPreset: SmartCompressionPreset.balanced,
            selectedTargetSizeRatio: 0.6,
            availableEncoderBackends: const [EncoderBackend.auto],
            onClose: () {},
            onOpenSource: () {},
            onSave: () {},
            onCompressionModeChanged: (_) {},
            onSmartPresetChanged: (_) {},
            onTargetSizeRatioChanged: ratioChanges.add,
            onQualityChanged: (_) {},
            onOutputFormatChanged: (_) {},
            onVideoCodecChanged: (_) {},
            onEncoderBackendChanged: (_) {},
            onResolutionPresetChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsNothing);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('目标体积'), findsOneWidget);
    expect(find.text('压缩体积60%'), findsOneWidget);
    expect(find.text('60%'), findsWidgets);

    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged?.call(8);

    expect(ratioChanges, [0.9]);
  });

  testWidgets('dark theme segmented slider thumb uses primary color', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: frameLeanDarkTheme(),
        home: Scaffold(
          body: _TestTaskConfigDialog(
            task: testTask(
              config: VideoTaskConfig.initial().copyWith(
                compressionMode: CompressionMode.targetSize,
                targetSizeRatio: 0.6,
              ),
            ),
            thumbnail: null,
            selectedQualityIndex: 3,
            selectedOutputFormat: OutputFormat.mp4,
            selectedVideoCodec: VideoCodec.h264,
            selectedEncoderBackend: EncoderBackend.auto,
            selectedResolutionPreset: ResolutionPreset.original,
            selectedCompressionMode: CompressionMode.targetSize,
            selectedSmartPreset: SmartCompressionPreset.balanced,
            selectedTargetSizeRatio: 0.6,
            availableEncoderBackends: const [EncoderBackend.auto],
            onClose: () {},
            onOpenSource: () {},
            onSave: () {},
            onCompressionModeChanged: (_) {},
            onSmartPresetChanged: (_) {},
            onTargetSizeRatioChanged: (_) {},
            onQualityChanged: (_) {},
            onOutputFormatChanged: (_) {},
            onVideoCodecChanged: (_) {},
            onEncoderBackendChanged: (_) {},
            onResolutionPresetChanged: (_) {},
          ),
        ),
      ),
    );

    final sliderTheme = tester.widget<SliderTheme>(find.byType(SliderTheme));

    expect(sliderTheme.data.thumbColor, frameLeanDarkColors.primary);
  });

  testWidgets('image task configuration exposes image controls', (
    tester,
  ) async {
    final imageChanges = <ImageProcessingConfig>[];
    final initialConfig = ImageProcessingConfig.initial().copyWith(
      imageQuality: 80,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _TestTaskConfigDialog(
            task: imageTask(config: initialConfig),
            thumbnail: null,
            selectedQualityIndex: 4,
            selectedOutputFormat: OutputFormat.mp4,
            selectedVideoCodec: VideoCodec.h264,
            selectedEncoderBackend: EncoderBackend.auto,
            selectedResolutionPreset: ResolutionPreset.original,
            selectedCompressionMode: CompressionMode.preset,
            selectedSmartPreset: SmartCompressionPreset.balanced,
            selectedTargetSizeRatio: 0.6,
            selectedImageConfig: initialConfig,
            availableEncoderBackends: const [EncoderBackend.auto],
            onClose: () {},
            onOpenSource: () {},
            onSave: () {},
            onCompressionModeChanged: (_) {},
            onSmartPresetChanged: (_) {},
            onTargetSizeRatioChanged: (_) {},
            onQualityChanged: (_) {},
            onOutputFormatChanged: (_) {},
            onVideoCodecChanged: (_) {},
            onEncoderBackendChanged: (_) {},
            onResolutionPresetChanged: (_) {},
            onImageConfigChanged: imageChanges.add,
          ),
        ),
      ),
    );

    expect(find.text('图片格式'), findsOneWidget);
    expect(find.text('分辨率'), findsOneWidget);
    expect(find.text('质量'), findsOneWidget);
    expect(find.text('无损压缩'), findsOneWidget);
    expect(find.text('保留80%的质量'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('图片编码'), findsNothing);
    expect(find.text('尺寸'), findsNothing);
    expect(find.text('保留元数据'), findsOneWidget);
    expect(find.text('视频编码'), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(Checkbox), findsNWidgets(2));
    expect(find.text('开启'), findsNothing);
    expect(find.text('关闭'), findsNothing);
    expect(
      tester.getCenter(find.byType(Checkbox).first).dy,
      tester.getCenter(find.byType(Checkbox).last).dy,
    );

    final formatDropdown = tester.widget<ConfigDropdown<MediaOutputFormat>>(
      find
          .byWidgetPredicate(
            (widget) => widget is ConfigDropdown<MediaOutputFormat>,
          )
          .first,
    );
    expect(
      formatDropdown.values,
      MediaOutputFormat.formatsFor(MediaKind.image),
    );
    expect(formatDropdown.values, isNot(contains(MediaOutputFormat.mp3)));
    formatDropdown.onChanged(MediaOutputFormat.webp);

    final resizeDropdown = tester
        .widget<DropdownButtonFormField<ImageResizePreset>>(
          find.byWidgetPredicate(
            (widget) => widget is DropdownButtonFormField<ImageResizePreset>,
          ),
        );
    resizeDropdown.onChanged?.call(ImageResizePreset.longEdge1280);

    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged?.call(9);

    final losslessCheckbox = tester.widget<Checkbox>(
      find.byType(Checkbox).first,
    );
    losslessCheckbox.onChanged?.call(true);

    final metadataCheckbox = tester.widget<Checkbox>(
      find.byType(Checkbox).last,
    );
    metadataCheckbox.onChanged?.call(false);

    expect(
      imageChanges.map((config) => config.outputFormat),
      contains(MediaOutputFormat.webp),
    );
    expect(
      imageChanges.map((config) => config.resizePreset),
      contains(ImageResizePreset.longEdge1280),
    );
    expect(imageChanges.map((config) => config.imageQuality), contains(100));
    expect(
      imageChanges.map((config) => config.losslessCompression),
      contains(true),
    );
    expect(
      imageChanges.map((config) => config.preserveMetadata),
      contains(false),
    );
  });

  testWidgets('lossless image compression hides quality and limits formats', (
    tester,
  ) async {
    final config = ImageProcessingConfig.initial().copyWith(
      outputFormat: MediaOutputFormat.webp,
      keepOriginalOutputFormat: false,
      losslessCompression: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _TestTaskConfigDialog(
            task: imageTask(config: config),
            thumbnail: null,
            selectedQualityIndex: 4,
            selectedOutputFormat: OutputFormat.mp4,
            selectedVideoCodec: VideoCodec.h264,
            selectedEncoderBackend: EncoderBackend.auto,
            selectedResolutionPreset: ResolutionPreset.original,
            selectedCompressionMode: CompressionMode.preset,
            selectedSmartPreset: SmartCompressionPreset.balanced,
            selectedTargetSizeRatio: 0.6,
            selectedImageConfig: config,
            availableEncoderBackends: const [EncoderBackend.auto],
            onClose: () {},
            onOpenSource: () {},
            onSave: () {},
            onCompressionModeChanged: (_) {},
            onSmartPresetChanged: (_) {},
            onTargetSizeRatioChanged: (_) {},
            onQualityChanged: (_) {},
            onOutputFormatChanged: (_) {},
            onVideoCodecChanged: (_) {},
            onEncoderBackendChanged: (_) {},
            onResolutionPresetChanged: (_) {},
            onImageConfigChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('无损压缩'), findsOneWidget);
    expect(find.text('质量'), findsNothing);
    final formatDropdown = tester.widget<ConfigDropdown<MediaOutputFormat>>(
      find
          .byWidgetPredicate(
            (widget) => widget is ConfigDropdown<MediaOutputFormat>,
          )
          .first,
    );
    expect(formatDropdown.values, const [
      MediaOutputFormat.png,
      MediaOutputFormat.webp,
      MediaOutputFormat.tiff,
    ]);
  });

  testWidgets('audio task configuration exposes audio controls', (
    tester,
  ) async {
    final audioChanges = <AudioProcessingConfig>[];
    final initialConfig = AudioProcessingConfig.initial();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _TestTaskConfigDialog(
            task: audioTask(config: initialConfig),
            thumbnail: null,
            selectedQualityIndex: 4,
            selectedOutputFormat: OutputFormat.mp4,
            selectedVideoCodec: VideoCodec.h264,
            selectedEncoderBackend: EncoderBackend.auto,
            selectedResolutionPreset: ResolutionPreset.original,
            selectedCompressionMode: CompressionMode.preset,
            selectedSmartPreset: SmartCompressionPreset.balanced,
            selectedTargetSizeRatio: 0.6,
            selectedAudioConfig: initialConfig,
            availableEncoderBackends: const [EncoderBackend.auto],
            onClose: () {},
            onOpenSource: () {},
            onSave: () {},
            onCompressionModeChanged: (_) {},
            onSmartPresetChanged: (_) {},
            onTargetSizeRatioChanged: (_) {},
            onQualityChanged: (_) {},
            onOutputFormatChanged: (_) {},
            onVideoCodecChanged: (_) {},
            onEncoderBackendChanged: (_) {},
            onResolutionPresetChanged: (_) {},
            onAudioConfigChanged: audioChanges.add,
          ),
        ),
      ),
    );

    expect(find.text('音频格式'), findsOneWidget);
    expect(find.text('音频编码'), findsNothing);
    expect(find.text('码率'), findsOneWidget);
    expect(find.text('采样率'), findsOneWidget);
    expect(find.text('声道'), findsOneWidget);
    expect(find.text('视频编码'), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(Checkbox), findsOneWidget);

    final formatDropdown = tester.widget<ConfigDropdown<MediaOutputFormat>>(
      find
          .byWidgetPredicate(
            (widget) => widget is ConfigDropdown<MediaOutputFormat>,
          )
          .first,
    );
    expect(
      formatDropdown.values,
      MediaOutputFormat.formatsFor(MediaKind.audio),
    );
    expect(formatDropdown.values, isNot(contains(MediaOutputFormat.png)));
    expect(formatDropdown.values, contains(MediaOutputFormat.opus));
    expect(formatDropdown.values, contains(MediaOutputFormat.oggOpus));
    formatDropdown.onChanged(MediaOutputFormat.mp3);

    final bitrateDropdown = tester
        .widget<DropdownButtonFormField<AudioBitratePreset>>(
          find.byWidgetPredicate(
            (widget) => widget is DropdownButtonFormField<AudioBitratePreset>,
          ),
        );
    bitrateDropdown.onChanged?.call(AudioBitratePreset.k128);

    final channelsDropdown = tester
        .widget<DropdownButtonFormField<AudioChannelsPreset>>(
          find.byWidgetPredicate(
            (widget) => widget is DropdownButtonFormField<AudioChannelsPreset>,
          ),
        );
    channelsDropdown.onChanged?.call(AudioChannelsPreset.stereo);
    tester.widget<Checkbox>(find.byType(Checkbox)).onChanged?.call(false);

    expect(
      audioChanges.map((config) => config.outputFormat),
      contains(MediaOutputFormat.mp3),
    );
    expect(
      audioChanges.map((config) => config.bitratePreset),
      contains(AudioBitratePreset.k128),
    );
    expect(
      audioChanges.map((config) => config.channels),
      contains(AudioChannelsPreset.stereo),
    );
    expect(
      audioChanges.map((config) => config.preserveMetadata),
      contains(false),
    );
  });

  testWidgets('image conversion only exposes target format in main panel', (
    tester,
  ) async {
    await _pumpTaskConfigurationDialog(
      tester,
      task: imageTask(config: ImageProcessingConfig.initial()),
      selectedPurpose: TaskPurpose.conversion,
    );

    expect(find.text('目标格式'), findsOneWidget);
    expect(find.text('质量'), findsNothing);
    expect(find.text('分辨率'), findsNothing);
    expect(find.text('无损压缩'), findsNothing);
    expect(find.text('高级设置'), findsOneWidget);
  });

  testWidgets('audio conversion hides compression controls', (tester) async {
    await _pumpTaskConfigurationDialog(
      tester,
      task: audioTask(config: AudioProcessingConfig.initial()),
      selectedPurpose: TaskPurpose.conversion,
    );

    expect(find.text('目标格式'), findsOneWidget);
    expect(find.text('码率'), findsNothing);
    expect(find.text('采样率'), findsNothing);
    expect(find.text('声道'), findsNothing);
    expect(find.text('高级设置'), findsOneWidget);
  });

  testWidgets('video conversion hides codec resolution and quality controls', (
    tester,
  ) async {
    await _pumpTaskConfigurationDialog(
      tester,
      selectedPurpose: TaskPurpose.conversion,
    );

    expect(find.text('目标格式'), findsOneWidget);
    expect(find.text('视频编码'), findsNothing);
    expect(find.text('分辨率'), findsNothing);
    expect(find.text('推荐方案'), findsNothing);
    expect(find.text('两遍压缩'), findsNothing);
    expect(find.text('高级设置'), findsOneWidget);
  });

  testWidgets('folder configuration shows aggregate summary', (tester) async {
    final folder = TaskFolder.create(
      name: '视频任务夹 1',
      mediaKind: MediaKind.video,
      sortOrder: 0,
      defaultConfig: MediaTaskConfig.initialVideo(),
    );
    final tasks = [
      testTask(fileName: 'first.mp4').copyWith(
        sourceFileFingerprint: const SourceFileFingerprint(
          fileSize: 1024,
          lastModifiedAt: 1,
        ),
        analysisResult: MediaAnalysisResult(
          durationMs: 1000,
          containerFormat: 'mp4',
        ),
      ),
      testTask(fileName: 'second.mov').copyWith(
        sourceFileFingerprint: const SourceFileFingerprint(
          fileSize: 2048,
          lastModifiedAt: 1,
        ),
        analysisResult: MediaAnalysisResult(
          durationMs: 2000,
          containerFormat: 'mov',
        ),
      ),
    ];

    await _pumpTaskConfigurationDialog(
      tester,
      sourceSummary: WorkbenchTaskFolderSummary(folder: folder, tasks: tasks),
    );

    expect(find.text('任务数量: 2'), findsOneWidget);
    expect(find.textContaining('源文件总大小:'), findsOneWidget);
    expect(find.textContaining('MP4 × 1'), findsOneWidget);
    expect(find.textContaining('MOV × 1'), findsOneWidget);
    expect(find.textContaining('总时长:'), findsOneWidget);
    expect(find.textContaining('源文件大小:'), findsNothing);
  });

  testWidgets(
    'task configuration keeps header and actions fixed while body scrolls',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 400);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final purposeChanges = <TaskPurpose>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.macOS),
          home: Scaffold(
            body: _TestTaskConfigDialog(
              task: testTask(),
              thumbnail: null,
              selectedQualityIndex: 4,
              selectedOutputFormat: OutputFormat.mp4,
              selectedVideoCodec: VideoCodec.h264,
              selectedEncoderBackend: EncoderBackend.auto,
              selectedResolutionPreset: ResolutionPreset.original,
              selectedCompressionMode: CompressionMode.preset,
              selectedSmartPreset: SmartCompressionPreset.balanced,
              selectedTargetSizeRatio: 0.6,
              availableEncoderBackends: const [EncoderBackend.auto],
              onClose: () {},
              onOpenSource: () {},
              onSave: () {},
              onPurposeChanged: purposeChanges.add,
              onCompressionModeChanged: (_) {},
              onSmartPresetChanged: (_) {},
              onTargetSizeRatioChanged: (_) {},
              onQualityChanged: (_) {},
              onOutputFormatChanged: (_) {},
              onVideoCodecChanged: (_) {},
              onEncoderBackendChanged: (_) {},
              onResolutionPresetChanged: (_) {},
            ),
          ),
        ),
      );

      final purposeControlFinder = find.byWidgetPredicate(
        (widget) => widget is CupertinoSlidingSegmentedControl<TaskPurpose>,
      );
      final purposeControl = tester
          .widget<CupertinoSlidingSegmentedControl<TaskPurpose>>(
            purposeControlFinder,
          );
      purposeControl.onValueChanged(TaskPurpose.conversion);
      expect(purposeChanges, [TaskPurpose.conversion]);

      final scrollViewFinder = find.byType(SingleChildScrollView);
      final scrollView = tester.widget<SingleChildScrollView>(scrollViewFinder);
      final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar));
      final scrollController = scrollView.controller!;
      expect(find.byType(Scrollbar), findsOneWidget);
      expect(scrollView.physics, isA<ClampingScrollPhysics>());
      expect(scrollView.padding, isNull);
      expect(
        find.ancestor(
          of: scrollViewFinder,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.margin == const EdgeInsets.fromLTRB(2, 0, 12, 0),
          ),
        ),
        findsOneWidget,
      );
      expect(scrollbar.controller, same(scrollController));
      expect(scrollbar.thumbVisibility, isFalse);
      expect(scrollbar.trackVisibility, isFalse);
      expect(scrollbar.thickness, 4);
      expect(scrollbar.radius, const Radius.circular(4));
      expect(scrollbar.interactive, isTrue);
      final topGesture = await tester.startGesture(
        tester.getCenter(scrollViewFinder),
      );
      await topGesture.moveBy(const Offset(0, 80));
      await tester.pump();
      expect(
        scrollController.offset,
        scrollController.position.minScrollExtent,
      );
      await topGesture.up();
      await tester.pumpAndSettle();

      final headerBefore = tester.getCenter(
        find.byType(AppDialogBackHeader),
      );
      final actionsBefore = tester.getCenter(
        find.byType(AppDialogActions),
      );
      final sourceBefore = tester.getCenter(find.textContaining('源文件大小'));

      await tester.drag(scrollViewFinder, const Offset(0, -180));
      await tester.pumpAndSettle();

      expect(
        tester.getCenter(find.byType(AppDialogBackHeader)),
        headerBefore,
      );
      expect(
        tester.getCenter(find.byType(AppDialogActions)),
        actionsBefore,
      );
      expect(
        tester.getCenter(find.textContaining('源文件大小')).dy,
        lessThan(sourceBefore.dy),
      );

      scrollController.jumpTo(scrollController.position.maxScrollExtent);
      await tester.pump();
      final bottomGesture = await tester.startGesture(
        tester.getCenter(scrollViewFinder),
      );
      await bottomGesture.moveBy(const Offset(0, -80));
      await tester.pump();
      expect(
        scrollController.offset,
        scrollController.position.maxScrollExtent,
      );
      await bottomGesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('already compressed source shows no estimated size text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _TestTaskConfigDialog(
            task: testTask(
              analysisResult: MediaAnalysisResult(
                durationMs: 60000,
                videoWidth: 3840,
                videoHeight: 2160,
                videoCodec: 'hevc',
                videoBitrate: 3000000,
                audioBitrate: 128000,
              ),
            ),
            thumbnail: null,
            selectedQualityIndex: 4,
            selectedOutputFormat: OutputFormat.mp4,
            selectedVideoCodec: VideoCodec.h264,
            selectedEncoderBackend: EncoderBackend.auto,
            selectedResolutionPreset: ResolutionPreset.original,
            selectedCompressionMode: CompressionMode.preset,
            selectedSmartPreset: SmartCompressionPreset.balanced,
            selectedTargetSizeRatio: 0.6,
            availableEncoderBackends: const [EncoderBackend.auto],
            onClose: () {},
            onOpenSource: () {},
            onSave: () {},
            onCompressionModeChanged: (_) {},
            onSmartPresetChanged: (_) {},
            onTargetSizeRatioChanged: (_) {},
            onQualityChanged: (_) {},
            onOutputFormatChanged: (_) {},
            onVideoCodecChanged: (_) {},
            onEncoderBackendChanged: (_) {},
            onResolutionPresetChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.textContaining('约'), findsNothing);
    expect(find.text('文件已压缩，不保证更小'), findsNothing);
    expect(find.text('已压缩'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppDialogActions),
        matching: find.text('已压缩'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('already compressed target size mode hides target bytes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _TestTaskConfigDialog(
            task: testTask(
              config: VideoTaskConfig.initial().copyWith(
                compressionMode: CompressionMode.targetSize,
                targetSizeRatio: 0.4,
              ),
              analysisResult: MediaAnalysisResult(
                durationMs: 60000,
                videoWidth: 3840,
                videoHeight: 2160,
                videoCodec: 'hevc',
                videoBitrate: 3000000,
                audioBitrate: 128000,
              ),
            ),
            thumbnail: null,
            selectedQualityIndex: 3,
            selectedOutputFormat: OutputFormat.mp4,
            selectedVideoCodec: VideoCodec.h264,
            selectedEncoderBackend: EncoderBackend.auto,
            selectedResolutionPreset: ResolutionPreset.original,
            selectedCompressionMode: CompressionMode.targetSize,
            selectedSmartPreset: SmartCompressionPreset.balanced,
            selectedTargetSizeRatio: 0.4,
            availableEncoderBackends: const [EncoderBackend.auto],
            onClose: () {},
            onOpenSource: () {},
            onSave: () {},
            onCompressionModeChanged: (_) {},
            onSmartPresetChanged: (_) {},
            onTargetSizeRatioChanged: (_) {},
            onQualityChanged: (_) {},
            onOutputFormatChanged: (_) {},
            onVideoCodecChanged: (_) {},
            onEncoderBackendChanged: (_) {},
            onResolutionPresetChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('文件已压缩，不保证更小'), findsNothing);
    expect(find.text('已压缩'), findsOneWidget);
    expect(find.textContaining('压缩至'), findsNothing);
  });

  testWidgets('missing source task action relinks instead of retrying', (
    tester,
  ) async {
    var relinkCount = 0;
    var retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaTaskListTile(
            task: testTask(status: TaskStatus.missingSource),
            onRelink: () {
              relinkCount += 1;
            },
            onRetry: () {
              retryCount += 1;
            },
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.link_rounded), findsOneWidget);
    expect(find.byTooltip('重新链接源文件'), findsOneWidget);

    await tester.tap(find.byTooltip('重新链接源文件'));
    await tester.pump();

    expect(relinkCount, 1);
    expect(retryCount, 0);
  });

  testWidgets('analyzed pending task starts instead of retrying', (
    tester,
  ) async {
    var startCount = 0;
    var retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaTaskListTile(
            task: testTask(status: TaskStatus.pending),
            onStart: () {
              startCount += 1;
            },
            onRetry: () {
              retryCount += 1;
            },
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.play_circle_fill_rounded), findsOneWidget);
    expect(find.byTooltip('开始压缩'), findsOneWidget);
    expect(find.byTooltip('重试任务'), findsNothing);

    await tester.tap(find.byTooltip('开始压缩'));
    await tester.pump();

    expect(startCount, 1);
    expect(retryCount, 0);
  });

  testWidgets('task action button does not also open the task tile', (
    tester,
  ) async {
    var startCount = 0;
    var openCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaTaskListTile(
            task: testTask(status: TaskStatus.pending),
            onTap: () {
              openCount += 1;
            },
            onStart: () {
              startCount += 1;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('开始压缩'));
    await tester.pump();

    expect(startCount, 1);
    expect(openCount, 0);
  });

  testWidgets('pending task without analysis has no primary action', (
    tester,
  ) async {
    var startCount = 0;
    var retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaTaskListTile(
            task: testTask(
              status: TaskStatus.pending,
              hasAnalysisResult: false,
            ),
            onStart: () {
              startCount += 1;
            },
            onRetry: () {
              retryCount += 1;
            },
          ),
        ),
      ),
    );

    expect(find.byTooltip('开始压缩'), findsNothing);
    expect(find.byTooltip('重试任务'), findsNothing);

    expect(startCount, 0);
    expect(retryCount, 0);
  });

  testWidgets('paused task continues with a different icon than start', (
    tester,
  ) async {
    var startCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaTaskListTile(
            task: testTask(status: TaskStatus.paused),
            onStart: () {
              startCount += 1;
            },
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_fill_rounded), findsNothing);
    expect(find.byTooltip('继续任务'), findsOneWidget);

    await tester.tap(find.byTooltip('继续任务'));
    await tester.pump();

    expect(startCount, 1);
  });

  testWidgets('failed task retries instead of starting', (tester) async {
    var startCount = 0;
    var retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaTaskListTile(
            task: testTask(status: TaskStatus.failed),
            onStart: () {
              startCount += 1;
            },
            onRetry: () {
              retryCount += 1;
            },
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    expect(find.byTooltip('重试任务'), findsOneWidget);
    expect(find.byTooltip('开始压缩'), findsNothing);

    await tester.tap(find.byTooltip('重试任务'));
    await tester.pump();

    expect(startCount, 0);
    expect(retryCount, 1);
  });

  testWidgets('completed task shows restart action', (tester) async {
    var retryCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaTaskListTile(
            task: testTask(status: TaskStatus.completed),
            onRetry: () {
              retryCount += 1;
            },
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.replay_rounded), findsOneWidget);
    expect(find.byTooltip('重来'), findsOneWidget);
    expect(find.byTooltip('重试任务'), findsNothing);

    await tester.tap(find.byTooltip('重来'));
    await tester.pump();

    expect(retryCount, 1);
  });

  testWidgets('completed compression task shows size reduction summary', (
    tester,
  ) async {
    final task = testTask(
      status: TaskStatus.completed,
    ).copyWith(outputFileSize: 60 * 1024 * 1024);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MediaTaskListTile(task: task)),
      ),
    );

    expect(find.text('100MB - 60MB · 压缩了40%'), findsOneWidget);
  });

  testWidgets('completed conversion task shows formats without percentage', (
    tester,
  ) async {
    final task =
        testTask(
          status: TaskStatus.completed,
          config: VideoTaskConfig.initial().copyWith(
            outputFormat: OutputFormat.mov,
          ),
        ).copyWith(
          purpose: TaskPurpose.conversion,
          outputFileSize: 60 * 1024 * 1024,
        );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MediaTaskListTile(task: task)),
      ),
    );

    expect(find.text('MP4 - MOV'), findsOneWidget);
    expect(find.textContaining('压缩了'), findsNothing);
  });

  testWidgets('task list placeholder thumbnails match media kind', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MediaTaskListTile(task: testTask()),
              MediaTaskListTile(task: imageTask()),
              MediaTaskListTile(task: audioTask()),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.movie_creation_outlined), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(find.byIcon(Icons.audiotrack_rounded), findsOneWidget);
  });

  testWidgets('source summary placeholder thumbnails match media kind', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              WorkbenchSourceSummary(task: testTask(), thumbnail: null),
              WorkbenchSourceSummary(task: imageTask(), thumbnail: null),
              WorkbenchSourceSummary(task: audioTask(), thumbnail: null),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.movie_creation_outlined), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(find.byIcon(Icons.audiotrack_rounded), findsOneWidget);
  });

  testWidgets('restart unelevated dialog warns about active tasks', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConfirmDialog(
            title: '普通模式重启',
            body: '当前有任务正在处理。普通模式重启会关闭当前管理员窗口，并中断正在执行的任务。',
            confirmLabel: '重启',
          ),
        ),
      ),
    );

    expect(find.text('普通模式重启'), findsOneWidget);
    expect(find.textContaining('中断正在执行的任务'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('重启'), findsOneWidget);
  });

  testWidgets('windows shell reserves a top notice safe area', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    var notificationsTapped = false;
    var themeTapped = false;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkbenchShell(
              taskList: AsyncData([testTask()]),
              taskFolders: const AsyncData([]),
              selectedTaskIds: const {},
              selectionMode: false,
              importEnabled: true,
              importDragging: false,
              hasRunningTask: false,
              queueActionInFlight: false,
              thumbnailForTask: (_) => null,
              onImportDraggingChanged: (_) {},
              onImportDrop: (_) {},
              onReorder: (_, _) {},
              onOpenTask: (_) {},
              onStart: (_) {},
              onPause: (_) {},
              onRemove: (_) {},
              onRetry: (_) {},
              onRelink: (_) {},
              onShowLog: (_) {},
              onRevealOutput: (_) {},
              onContextMenu: (_, _) {},
              onToggleSelectionMode: () {},
              onToggleTaskSelection: (_) {},
              onSelectTasksWithRectangle: (_, {toggle = false}) {},
              onCreateFolderFromSelection: () {},
              onMoveTaskToFolder: (_, _) {},
              onOpenFolderSettings: (_) {},
              onOpenFolderContents: (_) {},
              onStartFolder: (_) {},
              onPauseFolder: (_) {},
              onRetryFolder: (_) {},
              onRelinkFolder: (_) {},
              onShowFolderLog: (_) {},
              onDeleteFolder: (_) {},
              onAddTasks: () {},
              onOpenSettings: () {},
              themeMode: AppThemeMode.light,
              onToggleThemeMode: () {
                themeTapped = true;
              },
              onOpenNotifications: () {
                notificationsTapped = true;
              },
              unreadNotificationCount: 3,
              onClearTasks: () {},
              onPrimaryQueuePressed: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('windows-notice-safe-area')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(MediaTaskListTile)).dy,
        greaterThanOrEqualTo(topBarHeight + 30),
      );
      expect(find.byTooltip('通知中心'), findsOneWidget);
      expect(
        find.byKey(const Key('notification-unread-badge')),
        findsOneWidget,
      );
      expect(find.text('3'), findsOneWidget);
      expect(find.byTooltip('切换为深色模式'), findsOneWidget);

      await tester.tap(find.byTooltip('切换为深色模式'));
      await tester.pumpAndSettle();

      expect(themeTapped, isTrue);

      await tester.tap(find.byTooltip('通知中心'));
      await tester.pumpAndSettle();

      expect(notificationsTapped, isTrue);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('workbench shell shows folders and hides their child tasks', (
    tester,
  ) async {
    final settingsCalls = <String>[];
    final openCalls = <String>[];
    final deleteCalls = <String>[];
    final folder = TaskFolder(
      id: 'folder-1',
      name: '视频任务夹（1）',
      mediaKind: MediaKind.video,
      sortOrder: 0,
      defaultConfig: MediaTaskConfig.initialVideo(),
      createdAt: 1,
      updatedAt: 1,
    );
    final folderTask = testTask(
      fileName: 'inside.mp4',
    ).copyWith(id: 'inside', folderId: folder.id, folderSortOrder: 0);
    final looseTask = testTask(
      fileName: 'outside.mp4',
    ).copyWith(id: 'outside', sortOrder: 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkbenchShell(
            taskList: AsyncData([folderTask, looseTask]),
            taskFolders: AsyncData([folder]),
            selectedTaskIds: const {},
            selectionMode: false,
            importEnabled: true,
            importDragging: false,
            hasRunningTask: false,
            queueActionInFlight: false,
            thumbnailForTask: (_) => null,
            onImportDraggingChanged: (_) {},
            onImportDrop: (_) {},
            onReorder: (_, _) {},
            onOpenTask: (_) {},
            onStart: (_) {},
            onPause: (_) {},
            onRemove: (_) {},
            onRetry: (_) {},
            onRelink: (_) {},
            onShowLog: (_) {},
            onRevealOutput: (_) {},
            onContextMenu: (_, _) {},
            onToggleSelectionMode: () {},
            onToggleTaskSelection: (_) {},
            onSelectTasksWithRectangle: (_, {toggle = false}) {},
            onCreateFolderFromSelection: () {},
            onMoveTaskToFolder: (_, _) {},
            onOpenFolderSettings: (folder) {
              settingsCalls.add(folder.id);
            },
            onOpenFolderContents: (folder) {
              openCalls.add(folder.id);
            },
            onStartFolder: (_) {},
            onPauseFolder: (_) {},
            onRetryFolder: (_) {},
            onRelinkFolder: (_) {},
            onShowFolderLog: (_) {},
            onDeleteFolder: (folder) {
              deleteCalls.add(folder.id);
            },
            onAddTasks: () {},
            onOpenSettings: () {},
            themeMode: AppThemeMode.light,
            onToggleThemeMode: () {},
            onOpenNotifications: () {},
            onClearTasks: () {},
            onPrimaryQueuePressed: () {},
          ),
        ),
      ),
    );

    expect(find.text('视频任务夹（1）'), findsOneWidget);
    expect(find.text('outside.mp4'), findsOneWidget);
    expect(find.text('inside.mp4'), findsNothing);
    expect(find.textContaining('1 个任务'), findsOneWidget);

    await tester.tap(find.text('视频任务夹（1）'));
    await tester.pumpAndSettle();
    expect(settingsCalls, ['folder-1']);
    expect(openCalls, isEmpty);

    await tester.tap(find.byTooltip('查看夹内任务'));
    await tester.pumpAndSettle();
    expect(openCalls, ['folder-1']);

    await tester.tap(find.byTooltip('删除任务夹并释放任务'));
    await tester.pumpAndSettle();
    expect(deleteCalls, ['folder-1']);
    expect(openCalls, ['folder-1']);
  });

  testWidgets('task folder progress background only shows while running', (
    tester,
  ) async {
    final folder = TaskFolder(
      id: 'folder-progress',
      name: '视频任务夹（1）',
      mediaKind: MediaKind.video,
      sortOrder: 0,
      defaultConfig: MediaTaskConfig.initialVideo(),
      createdAt: 1,
      updatedAt: 1,
    );
    final runningTask = testTask(fileName: 'inside.mp4').copyWith(
      id: 'inside',
      folderId: folder.id,
      folderSortOrder: 0,
      status: TaskStatus.running,
      progress: 0.6,
    );

    Widget buildTile(MediaTask task) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 640,
              child: TaskFolderListTile(
                folder: folder,
                tasks: [task],
                onOpenSettings: () {},
                onOpenContents: () {},
                onDelete: () {},
                onPause: () {},
                onRetry: () {},
                onShowLog: () {},
              ),
            ),
          ),
        ),
      );
    }

    final progressFinder = find.byKey(
      const ValueKey('task-folder-progress-folder-progress'),
    );
    await tester.pumpWidget(buildTile(runningTask));

    expect(progressFinder, findsOneWidget);
    expect(find.byTooltip('暂停任务夹任务'), findsOneWidget);

    final completedTask = runningTask.copyWith(
      status: TaskStatus.completed,
      progress: 1,
    );
    await tester.pumpWidget(buildTile(completedTask));
    await tester.pumpAndSettle();

    expect(progressFinder, findsNothing);
    expect(find.text('1 个任务 · 已完成 1 · 失败 0'), findsOneWidget);
    expect(find.byTooltip('重来任务夹终态任务'), findsOneWidget);
    expect(find.byTooltip('查看夹内任务日志'), findsOneWidget);
    expect(find.byTooltip('查看夹内任务'), findsOneWidget);
    expect(find.byTooltip('删除任务夹并释放任务'), findsOneWidget);

    final tileContainer = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(TaskFolderListTile),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(
      (tileContainer.decoration! as BoxDecoration).color,
      frameLeanLightColors.surface,
    );
  });

  testWidgets('folder content panel reuses task tile actions', (tester) async {
    final folder = TaskFolder(
      id: 'folder-1',
      name: '视频任务夹（1）',
      mediaKind: MediaKind.video,
      sortOrder: 0,
      defaultConfig: MediaTaskConfig.initialVideo(),
      createdAt: 1,
      updatedAt: 1,
    );
    final task = testTask(
      fileName: 'inside.mp4',
    ).copyWith(id: 'inside', folderId: folder.id, folderSortOrder: 0);
    var startCount = 0;
    var removeCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              TaskFolderContentPanel(
                visible: true,
                folder: folder,
                tasks: [task],
                thumbnailForTask: (_) => null,
                onClose: () {},
                onRemoveTask: (_) async {
                  removeCount += 1;
                },
                onStart: (_) {
                  startCount += 1;
                },
                onPause: (_) {},
                onRetry: (_) {},
                onRelink: (_) {},
                onShowLog: (_) {},
                onRevealOutput: (_) {},
                onReorder: (_, _) {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(MediaTaskListTile), findsOneWidget);
    expect(find.text('inside.mp4'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_circle_fill_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.remove_circle_outline_rounded));
    await tester.pump();

    expect(startCount, 1);
    expect(removeCount, 1);
  });

  testWidgets('folder task dragged onto scrim is removed in place', (
    tester,
  ) async {
    final folder = TaskFolder(
      id: 'folder-1',
      name: '视频任务夹（2）',
      mediaKind: MediaKind.video,
      sortOrder: 0,
      defaultConfig: MediaTaskConfig.initialVideo(),
      createdAt: 1,
      updatedAt: 1,
    );
    final firstTask = testTask(
      fileName: 'first.mp4',
    ).copyWith(id: 'first', folderId: folder.id, folderSortOrder: 0);
    final secondTask = testTask(
      fileName: 'second.mp4',
    ).copyWith(id: 'second', folderId: folder.id, folderSortOrder: 1);
    final removeCompleter = Completer<void>();
    final removeCalls = <String>[];
    final reorderCalls = <(int, int)>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              TaskFolderContentPanel(
                visible: true,
                folder: folder,
                tasks: [firstTask, secondTask],
                thumbnailForTask: (_) => null,
                onClose: () {},
                onRemoveTask: (task) {
                  removeCalls.add(task.id);
                  return removeCompleter.future;
                },
                onStart: (_) {},
                onPause: (_) {},
                onRetry: (_) {},
                onRelink: (_) {},
                onShowLog: (_) {},
                onRevealOutput: (_) {},
                onReorder: (oldIndex, newIndex) {
                  reorderCalls.add((oldIndex, newIndex));
                },
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(FrameLeanReorderableListView), findsOneWidget);
    expect(find.byType(ReorderableListView), findsNothing);
    final scrimFinder = find.byKey(const Key('task-folder-drop-scrim'));
    final beforeScrimColor =
        (tester.widget<AnimatedContainer>(scrimFinder).decoration!
                as BoxDecoration)
            .color;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.drag_indicator_rounded).first),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(const Offset(650, 300));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();

    final activeScrimColor =
        (tester.widget<AnimatedContainer>(scrimFinder).decoration!
                as BoxDecoration)
            .color;
    expect(activeScrimColor, isNot(beforeScrimColor));

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 20));
    expect(removeCalls, ['first']);
    expect(reorderCalls, isEmpty);
    expect(
      find.byKey(const Key('task-folder-accepted-drop-proxy')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('first.mp4'), findsNothing);
    expect(find.text('second.mp4'), findsOneWidget);
    expect(tester.takeException(), isNull);

    removeCompleter.complete();
    await tester.pump();
  });

  testWidgets('folder task dropped on panel header cancels removal', (
    tester,
  ) async {
    final folder = TaskFolder(
      id: 'folder-1',
      name: '视频任务夹（1）',
      mediaKind: MediaKind.video,
      sortOrder: 0,
      defaultConfig: MediaTaskConfig.initialVideo(),
      createdAt: 1,
      updatedAt: 1,
    );
    final task = testTask(
      fileName: 'inside.mp4',
    ).copyWith(id: 'inside', folderId: folder.id, folderSortOrder: 0);
    final removeCalls = <String>[];
    final reorderCalls = <(int, int)>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              TaskFolderContentPanel(
                visible: true,
                folder: folder,
                tasks: [task],
                thumbnailForTask: (_) => null,
                onClose: () {},
                onRemoveTask: (task) async {
                  removeCalls.add(task.id);
                },
                onStart: (_) {},
                onPause: (_) {},
                onRetry: (_) {},
                onRelink: (_) {},
                onShowLog: (_) {},
                onRevealOutput: (_) {},
                onReorder: (oldIndex, newIndex) {
                  reorderCalls.add((oldIndex, newIndex));
                },
              ),
            ],
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.drag_indicator_rounded)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(
      tester.getCenter(find.byIcon(Icons.folder_open_rounded)),
    );
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(removeCalls, isEmpty);
    expect(reorderCalls, isEmpty);
    expect(find.text('inside.mp4'), findsOneWidget);
  });

  testWidgets('folder task removal failure restores the task row', (
    tester,
  ) async {
    final folder = TaskFolder(
      id: 'folder-1',
      name: '视频任务夹（1）',
      mediaKind: MediaKind.video,
      sortOrder: 0,
      defaultConfig: MediaTaskConfig.initialVideo(),
      createdAt: 1,
      updatedAt: 1,
    );
    final task = testTask(
      fileName: 'inside.mp4',
    ).copyWith(id: 'inside', folderId: folder.id, folderSortOrder: 0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              TaskFolderContentPanel(
                visible: true,
                folder: folder,
                tasks: [task],
                thumbnailForTask: (_) => null,
                onClose: () {},
                onRemoveTask: (_) async {
                  throw StateError('save failed');
                },
                onStart: (_) {},
                onPause: (_) {},
                onRetry: (_) {},
                onRelink: (_) {},
                onShowLog: (_) {},
                onRevealOutput: (_) {},
                onReorder: (_, _) {},
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.remove_circle_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('inside.mp4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('running folder task cannot be dragged onto the scrim', (
    tester,
  ) async {
    final folder = TaskFolder(
      id: 'folder-1',
      name: '视频任务夹（1）',
      mediaKind: MediaKind.video,
      sortOrder: 0,
      defaultConfig: MediaTaskConfig.initialVideo(),
      createdAt: 1,
      updatedAt: 1,
    );
    final task = testTask(fileName: 'running.mp4').copyWith(
      id: 'running',
      folderId: folder.id,
      folderSortOrder: 0,
      status: TaskStatus.running,
    );
    final removeCalls = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              TaskFolderContentPanel(
                visible: true,
                folder: folder,
                tasks: [task],
                thumbnailForTask: (_) => null,
                onClose: () {},
                onRemoveTask: (task) async {
                  removeCalls.add(task.id);
                },
                onStart: (_) {},
                onPause: (_) {},
                onRetry: (_) {},
                onRelink: (_) {},
                onShowLog: (_) {},
                onRevealOutput: (_) {},
                onReorder: (_, _) {},
              ),
            ],
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.drag_indicator_rounded)),
    );
    await gesture.moveTo(const Offset(650, 300));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(removeCalls, isEmpty);
    expect(find.text('running.mp4'), findsOneWidget);
  });

  testWidgets(
    'folder reorder remains optimistic while persistence is pending',
    (tester) async {
      final folder = TaskFolder(
        id: 'folder-1',
        name: '视频任务夹（2）',
        mediaKind: MediaKind.video,
        sortOrder: 0,
        defaultConfig: MediaTaskConfig.initialVideo(),
        createdAt: 1,
        updatedAt: 1,
      );
      final firstTask = testTask(
        fileName: 'first.mp4',
      ).copyWith(id: 'first', folderId: folder.id, folderSortOrder: 0);
      final secondTask = testTask(
        fileName: 'second.mp4',
      ).copyWith(id: 'second', folderId: folder.id, folderSortOrder: 1);
      final reorderCompleter = Completer<void>();
      final reorderCalls = <(int, int)>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                TaskFolderContentPanel(
                  visible: true,
                  folder: folder,
                  tasks: [firstTask, secondTask],
                  thumbnailForTask: (_) => null,
                  onClose: () {},
                  onRemoveTask: (_) async {},
                  onStart: (_) {},
                  onPause: (_) {},
                  onRetry: (_) {},
                  onRelink: (_) {},
                  onShowLog: (_) {},
                  onRevealOutput: (_) {},
                  onReorder: (oldIndex, newIndex) {
                    reorderCalls.add((oldIndex, newIndex));
                    return reorderCompleter.future;
                  },
                ),
              ],
            ),
          ),
        ),
      );

      final firstTop = tester.getTopLeft(find.text('first.mp4')).dy;
      final dragHandles = find.byIcon(Icons.drag_indicator_rounded);
      final firstHandleCenter = tester.getCenter(dragHandles.first);
      final gesture = await tester.startGesture(
        tester.getCenter(dragHandles.last),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(firstHandleCenter);
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));

      expect(reorderCalls, isNotEmpty);
      expect(
        tester.getTopLeft(find.text('second.mp4')).dy,
        closeTo(firstTop, 0.1),
      );

      reorderCompleter.complete();
      await tester.pump();
    },
  );

  testWidgets('multi select mode shows checkbox and create folder FAB', (
    tester,
  ) async {
    var toggleModeCount = 0;
    var createFolderCount = 0;
    final task = testTask(fileName: 'outside.mp4').copyWith(id: 'outside');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkbenchShell(
            taskList: AsyncData([task]),
            taskFolders: const AsyncData([]),
            selectedTaskIds: {task.id},
            selectionMode: true,
            importEnabled: true,
            importDragging: false,
            hasRunningTask: false,
            queueActionInFlight: false,
            thumbnailForTask: (_) => null,
            onImportDraggingChanged: (_) {},
            onImportDrop: (_) {},
            onReorder: (_, _) {},
            onOpenTask: (_) {},
            onStart: (_) {},
            onPause: (_) {},
            onRemove: (_) {},
            onRetry: (_) {},
            onRelink: (_) {},
            onShowLog: (_) {},
            onRevealOutput: (_) {},
            onContextMenu: (_, _) {},
            onToggleSelectionMode: () {
              toggleModeCount += 1;
            },
            onToggleTaskSelection: (_) {},
            onSelectTasksWithRectangle: (_, {toggle = false}) {},
            onCreateFolderFromSelection: () {
              createFolderCount += 1;
            },
            onMoveTaskToFolder: (_, _) {},
            onOpenFolderSettings: (_) {},
            onOpenFolderContents: (_) {},
            onStartFolder: (_) {},
            onPauseFolder: (_) {},
            onRetryFolder: (_) {},
            onRelinkFolder: (_) {},
            onShowFolderLog: (_) {},
            onDeleteFolder: (_) {},
            onAddTasks: () {},
            onOpenSettings: () {},
            themeMode: AppThemeMode.light,
            onToggleThemeMode: () {},
            onOpenNotifications: () {},
            onClearTasks: () {},
            onPrimaryQueuePressed: () {},
          ),
        ),
      ),
    );

    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.text('已选 1'), findsOneWidget);
    expect(find.text('创建任务夹'), findsOneWidget);

    await tester.tap(find.byTooltip('退出多选'));
    await tester.pump();
    expect(toggleModeCount, 1);

    await tester.tap(find.text('创建任务夹'));
    await tester.pump();
    expect(createFolderCount, 1);
  });

  testWidgets(
    'task drag handle dropped on matching folder body moves instead of reorders',
    (tester) async {
      final moveCalls = <String>[];
      final reorderCalls = <(int oldIndex, int newIndex)>[];
      final folder = TaskFolder(
        id: 'folder-1',
        name: '视频任务夹（1）',
        mediaKind: MediaKind.video,
        sortOrder: 0,
        defaultConfig: MediaTaskConfig.initialVideo(),
        createdAt: 1,
        updatedAt: 1,
      );
      final folderTask = testTask(
        fileName: 'inside.mp4',
      ).copyWith(id: 'inside', folderId: folder.id, folderSortOrder: 0);
      final looseTask = testTask(
        fileName: 'outside.mp4',
      ).copyWith(id: 'outside', sortOrder: 1);

      await _pumpWorkbenchShellForDragTest(
        tester,
        tasks: [folderTask, looseTask],
        folders: [folder],
        onReorder: (oldIndex, newIndex) {
          reorderCalls.add((oldIndex, newIndex));
        },
        onMoveTaskToFolder: (task, folder) {
          moveCalls.add('${task.id}->${folder.id}');
        },
      );

      final taskDragHandle = find.byIcon(Icons.drag_indicator_rounded).last;
      final folderBody = find.byKey(
        const ValueKey('task-folder-drop-state-folder-1'),
      );
      final folderRectBeforeHover = tester.getRect(folderBody);
      final gesture = await tester.startGesture(
        tester.getCenter(taskDragHandle),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(
        Offset(
          folderRectBeforeHover.center.dx,
          folderRectBeforeHover.bottom - 8,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.getRect(folderBody).top,
        closeTo(folderRectBeforeHover.top, 0.1),
      );
      await gesture.moveTo(folderRectBeforeHover.center);
      await tester.pump(const Duration(milliseconds: 300));

      final hoveredFolder = tester.widget<AnimatedOpacity>(folderBody);
      final folderRectWhileHovered = tester.getRect(folderBody);
      expect(hoveredFolder.opacity, 1);
      expect(
        folderRectWhileHovered.top,
        closeTo(folderRectBeforeHover.top, 0.1),
      );
      expect(reorderCalls, isEmpty);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(moveCalls, ['outside->folder-1']);
      expect(reorderCalls, isEmpty);
    },
  );

  testWidgets(
    'task drag handle switches to reorder only after leaving folder body',
    (tester) async {
      final moveCalls = <String>[];
      final reorderCalls = <(int oldIndex, int newIndex)>[];
      final folder = TaskFolder(
        id: 'folder-1',
        name: '视频任务夹（1）',
        mediaKind: MediaKind.video,
        sortOrder: 0,
        defaultConfig: MediaTaskConfig.initialVideo(),
        createdAt: 1,
        updatedAt: 1,
      );
      final folderTask = testTask(
        fileName: 'inside.mp4',
      ).copyWith(id: 'inside', folderId: folder.id, folderSortOrder: 0);
      final firstLooseTask = testTask(
        fileName: 'first.mp4',
      ).copyWith(id: 'first', sortOrder: 1);
      final secondLooseTask = testTask(
        fileName: 'second.mp4',
      ).copyWith(id: 'second', sortOrder: 2);

      await _pumpWorkbenchShellForDragTest(
        tester,
        tasks: [folderTask, firstLooseTask, secondLooseTask],
        folders: [folder],
        onReorder: (oldIndex, newIndex) {
          reorderCalls.add((oldIndex, newIndex));
        },
        onMoveTaskToFolder: (task, folder) {
          moveCalls.add('${task.id}->${folder.id}');
        },
      );

      final taskDragHandles = find.byIcon(Icons.drag_indicator_rounded);
      final secondTaskDragHandle = taskDragHandles.last;
      final folderBody = find.byKey(
        const ValueKey('task-folder-drop-state-folder-1'),
      );
      final firstTaskText = find.text('first.mp4');
      final folderRectBeforeHover = tester.getRect(folderBody);
      final gesture = await tester.startGesture(
        tester.getCenter(secondTaskDragHandle),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(tester.getCenter(folderBody));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        tester.getRect(folderBody).top,
        closeTo(folderRectBeforeHover.top, 0.1),
      );
      expect(reorderCalls, isEmpty);

      await gesture.moveTo(tester.getCenter(firstTaskText));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      await gesture.moveTo(folderRectBeforeHover.center);
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      expect(
        tester.getRect(folderBody).top,
        closeTo(folderRectBeforeHover.top, 0.1),
      );
      expect(reorderCalls, isEmpty);

      await gesture.moveTo(tester.getCenter(firstTaskText));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(moveCalls, isEmpty);
      expect(reorderCalls, isNotEmpty);
    },
  );

  testWidgets(
    'task reorder keeps the dropped visual order while persistence catches up',
    (tester) async {
      final reorderCalls = <(int oldIndex, int newIndex)>[];
      final firstTask = testTask(
        fileName: 'first.mp4',
      ).copyWith(id: 'first', sortOrder: 0);
      final secondTask = testTask(
        fileName: 'second.mp4',
      ).copyWith(id: 'second', sortOrder: 1);
      final thirdTask = testTask(
        fileName: 'third.mp4',
      ).copyWith(id: 'third', sortOrder: 2);

      await _pumpWorkbenchShellForDragTest(
        tester,
        tasks: [firstTask, secondTask, thirdTask],
        folders: const [],
        onReorder: (oldIndex, newIndex) {
          reorderCalls.add((oldIndex, newIndex));
        },
      );

      final slotTops = [
        tester.getTopLeft(find.text('first.mp4')).dy,
        tester.getTopLeft(find.text('second.mp4')).dy,
        tester.getTopLeft(find.text('third.mp4')).dy,
      ];
      final taskDragHandles = find.byIcon(Icons.drag_indicator_rounded);
      final gesture = await tester.startGesture(
        tester.getCenter(taskDragHandles.last),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(tester.getCenter(find.text('first.mp4')));
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));

      expect(reorderCalls, hasLength(1));
      final (oldIndex, newIndex) = reorderCalls.single;
      final visualIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
      expect(
        tester.getTopLeft(find.text('third.mp4')).dy,
        closeTo(slotTops[visualIndex], 0.1),
      );
    },
  );

  testWidgets('task rows never use selection borders', (tester) async {
    final task = testTask(fileName: 'ordinary.mp3').copyWith(id: 'ordinary');

    await _pumpWorkbenchShellForDragTest(
      tester,
      tasks: [task],
      folders: const [],
      selectedTaskIds: {task.id},
      selectionMode: true,
    );

    final tile = find.byType(MediaTaskListTile);
    final animatedContainer = tester.widget<AnimatedContainer>(
      find.descendant(of: tile, matching: find.byType(AnimatedContainer)),
    );
    final decoration = animatedContainer.foregroundDecoration! as BoxDecoration;
    expect(decoration.border!.top.color, frameLeanLightColors.border);
    expect(decoration.border!.top.width, 1);
  });

  testWidgets('task drag handle dropped on folder edge keeps reorder', (
    tester,
  ) async {
    final moveCalls = <String>[];
    final reorderCalls = <(int oldIndex, int newIndex)>[];
    final folder = TaskFolder(
      id: 'folder-1',
      name: '视频任务夹（1）',
      mediaKind: MediaKind.video,
      sortOrder: 0,
      defaultConfig: MediaTaskConfig.initialVideo(),
      createdAt: 1,
      updatedAt: 1,
    );
    final folderTask = testTask(
      fileName: 'inside.mp4',
    ).copyWith(id: 'inside', folderId: folder.id, folderSortOrder: 0);
    final looseTask = testTask(
      fileName: 'outside.mp4',
    ).copyWith(id: 'outside', sortOrder: 1);

    await _pumpWorkbenchShellForDragTest(
      tester,
      tasks: [folderTask, looseTask],
      folders: [folder],
      onReorder: (oldIndex, newIndex) {
        reorderCalls.add((oldIndex, newIndex));
      },
      onMoveTaskToFolder: (task, folder) {
        moveCalls.add('${task.id}->${folder.id}');
      },
    );

    final taskDragHandle = find.byIcon(Icons.drag_indicator_rounded).last;
    final folderRect = tester.getRect(
      find.byKey(const ValueKey('task-folder-drop-state-folder-1')),
    );
    final folderTopEdge = Offset(folderRect.center.dx, folderRect.top + 8);
    final gesture = await tester.startGesture(tester.getCenter(taskDragHandle));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(folderTopEdge);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(moveCalls, isEmpty);
    expect(reorderCalls, isNotEmpty);
  });

  testWidgets(
    'different-kind folder disables drop and remains a reorder target',
    (tester) async {
      final moveCalls = <String>[];
      final reorderCalls = <(int oldIndex, int newIndex)>[];
      final folder = TaskFolder(
        id: 'image-folder',
        name: '图片任务夹（1）',
        mediaKind: MediaKind.image,
        sortOrder: 0,
        defaultConfig: MediaTaskConfig.initialImage(),
        createdAt: 1,
        updatedAt: 1,
      );
      final folderTask = imageTask().copyWith(
        id: 'inside-image',
        folderId: folder.id,
        folderSortOrder: 0,
      );
      final looseTask = testTask(
        fileName: 'outside.mp4',
      ).copyWith(id: 'outside', sortOrder: 1);

      await _pumpWorkbenchShellForDragTest(
        tester,
        tasks: [folderTask, looseTask],
        folders: [folder],
        onReorder: (oldIndex, newIndex) {
          reorderCalls.add((oldIndex, newIndex));
        },
        onMoveTaskToFolder: (task, folder) {
          moveCalls.add('${task.id}->${folder.id}');
        },
      );

      final taskDragHandle = find.byIcon(Icons.drag_indicator_rounded).last;
      final folderBody = find.byKey(
        const ValueKey('task-folder-drop-state-image-folder'),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(taskDragHandle),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(tester.getCenter(folderBody));
      await tester.pump();

      final disabledState = tester.widget<AnimatedOpacity>(folderBody);
      expect(disabledState.opacity, lessThan(1));

      await gesture.up();
      await tester.pumpAndSettle();

      expect(moveCalls, isEmpty);
      expect(reorderCalls, isNotEmpty);
    },
  );

  testWidgets('notification badge can be hidden without losing unread count', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkbenchTopBar(
            themeMode: AppThemeMode.light,
            onToggleThemeMode: () {},
            onOpenNotifications: () {},
            unreadNotificationCount: 3,
            showNotificationBadge: false,
          ),
        ),
      ),
    );

    expect(find.byTooltip('通知中心'), findsOneWidget);
    expect(find.byKey(const Key('notification-unread-badge')), findsNothing);
  });

  testWidgets('task list drag handle starts reorder without layout exception', (
    tester,
  ) async {
    final reorderCalls = <(int oldIndex, int newIndex)>[];
    final firstTask = testTask(
      fileName: 'first.mp4',
    ).copyWith(id: 'task-1', sortOrder: 0);
    final secondTask = testTask(
      fileName: 'second.mp4',
    ).copyWith(id: 'task-2', sortOrder: 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkbenchShell(
            taskList: AsyncData([firstTask, secondTask]),
            taskFolders: const AsyncData([]),
            selectedTaskIds: const {},
            selectionMode: false,
            importEnabled: true,
            importDragging: false,
            hasRunningTask: false,
            queueActionInFlight: false,
            thumbnailForTask: (_) => null,
            onImportDraggingChanged: (_) {},
            onImportDrop: (_) {},
            onReorder: (oldIndex, newIndex) {
              reorderCalls.add((oldIndex, newIndex));
            },
            onOpenTask: (_) {},
            onStart: (_) {},
            onPause: (_) {},
            onRemove: (_) {},
            onRetry: (_) {},
            onRelink: (_) {},
            onShowLog: (_) {},
            onRevealOutput: (_) {},
            onContextMenu: (_, _) {},
            onToggleSelectionMode: () {},
            onToggleTaskSelection: (_) {},
            onSelectTasksWithRectangle: (_, {toggle = false}) {},
            onCreateFolderFromSelection: () {},
            onMoveTaskToFolder: (_, _) {},
            onOpenFolderSettings: (_) {},
            onOpenFolderContents: (_) {},
            onStartFolder: (_) {},
            onPauseFolder: (_) {},
            onRetryFolder: (_) {},
            onRelinkFolder: (_) {},
            onShowFolderLog: (_) {},
            onDeleteFolder: (_) {},
            onAddTasks: () {},
            onOpenSettings: () {},
            themeMode: AppThemeMode.light,
            onToggleThemeMode: () {},
            onOpenNotifications: () {},
            onClearTasks: () {},
            onPrimaryQueuePressed: () {},
          ),
        ),
      ),
    );

    final firstDragHandle = find.byIcon(Icons.drag_indicator_rounded).first;
    final gesture = await tester.startGesture(
      tester.getCenter(firstDragHandle),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 150));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(reorderCalls, isNotEmpty);
  });
}

Future<void> _pumpWorkbenchShellForDragTest(
  WidgetTester tester, {
  required List<MediaTask> tasks,
  required List<TaskFolder> folders,
  Set<String> selectedTaskIds = const {},
  bool selectionMode = false,
  void Function(int oldIndex, int newIndex)? onReorder,
  void Function(MediaTask task, TaskFolder folder)? onMoveTaskToFolder,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WorkbenchShell(
          taskList: AsyncData(tasks),
          taskFolders: AsyncData(folders),
          selectedTaskIds: selectedTaskIds,
          selectionMode: selectionMode,
          importEnabled: true,
          importDragging: false,
          hasRunningTask: false,
          queueActionInFlight: false,
          thumbnailForTask: (_) => null,
          onImportDraggingChanged: (_) {},
          onImportDrop: (_) {},
          onReorder: onReorder ?? (_, _) {},
          onOpenTask: (_) {},
          onStart: (_) {},
          onPause: (_) {},
          onRemove: (_) {},
          onRetry: (_) {},
          onRelink: (_) {},
          onShowLog: (_) {},
          onRevealOutput: (_) {},
          onContextMenu: (_, _) {},
          onToggleSelectionMode: () {},
          onToggleTaskSelection: (_) {},
          onSelectTasksWithRectangle: (_, {toggle = false}) {},
          onCreateFolderFromSelection: () {},
          onMoveTaskToFolder: onMoveTaskToFolder ?? (_, _) {},
          onOpenFolderSettings: (_) {},
          onOpenFolderContents: (_) {},
          onStartFolder: (_) {},
          onPauseFolder: (_) {},
          onRetryFolder: (_) {},
          onRelinkFolder: (_) {},
          onShowFolderLog: (_) {},
          onDeleteFolder: (_) {},
          onAddTasks: () {},
          onOpenSettings: () {},
          themeMode: AppThemeMode.light,
          onToggleThemeMode: () {},
          onOpenNotifications: () {},
          onClearTasks: () {},
          onPrimaryQueuePressed: () {},
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Test adapter: provides old WorkbenchTaskConfigurationDialog API on top
// of the new TaskConfigDialogTemplate, so existing widget tests keep working.
// ---------------------------------------------------------------------------

class _TestTaskConfigDialog extends StatelessWidget {
  const _TestTaskConfigDialog({
    super.key,
    required this.task,
    required this.thumbnail,
    this.sourceSummary,
    this.title = '任务详情设置',
    required this.selectedQualityIndex,
    required this.selectedOutputFormat,
    required this.selectedVideoCodec,
    required this.selectedEncoderBackend,
    required this.selectedResolutionPreset,
    required this.selectedCompressionMode,
    required this.selectedSmartPreset,
    required this.selectedTargetSizeRatio,
    this.selectedPurpose = TaskPurpose.compression,
    this.selectedConfig,
    this.showOutputLocationInMain = false,
    this.systemOutputDirectoryLabel = '使用应用设置',
    this.onPickOutputDirectory,
    this.selectedVideoConfig,
    this.selectedImageConfig,
    this.selectedAudioConfig,
    required this.availableEncoderBackends,
    required this.onClose,
    this.onOpenSource,
    required this.onSave,
    this.onPurposeChanged,
    required this.onCompressionModeChanged,
    required this.onSmartPresetChanged,
    required this.onTargetSizeRatioChanged,
    required this.onQualityChanged,
    required this.onOutputFormatChanged,
    required this.onVideoCodecChanged,
    required this.onEncoderBackendChanged,
    required this.onResolutionPresetChanged,
    this.onPreserveHdrChanged,
    this.onVideoPreserveMetadataChanged,
    this.onImageConfigChanged,
    this.onAudioConfigChanged,
    this.onThreadLimitChanged,
    this.onOutputLocationChanged,
    this.onTwoPassModeChanged,
    this.onSelectedAudioStreamIndexChanged,
  });

  final MediaTask task;
  final ImageProvider? thumbnail;
  final Widget? sourceSummary;
  final String title;
  final int selectedQualityIndex;
  final OutputFormat selectedOutputFormat;
  final VideoCodec selectedVideoCodec;
  final EncoderBackend selectedEncoderBackend;
  final ResolutionPreset selectedResolutionPreset;
  final CompressionMode selectedCompressionMode;
  final SmartCompressionPreset selectedSmartPreset;
  final double selectedTargetSizeRatio;
  final TaskPurpose selectedPurpose;
  final MediaTaskConfig? selectedConfig;
  final bool showOutputLocationInMain;
  final String systemOutputDirectoryLabel;
  final Future<String?> Function()? onPickOutputDirectory;
  final VideoProcessingConfig? selectedVideoConfig;
  final ImageProcessingConfig? selectedImageConfig;
  final AudioProcessingConfig? selectedAudioConfig;
  final List<EncoderBackend> availableEncoderBackends;
  final VoidCallback onClose;
  final VoidCallback? onOpenSource;
  final VoidCallback onSave;
  final ValueChanged<TaskPurpose>? onPurposeChanged;
  final ValueChanged<CompressionMode> onCompressionModeChanged;
  final ValueChanged<SmartCompressionPreset> onSmartPresetChanged;
  final ValueChanged<double> onTargetSizeRatioChanged;
  final ValueChanged<int> onQualityChanged;
  final ValueChanged<OutputFormat> onOutputFormatChanged;
  final ValueChanged<VideoCodec> onVideoCodecChanged;
  final ValueChanged<EncoderBackend> onEncoderBackendChanged;
  final ValueChanged<ResolutionPreset> onResolutionPresetChanged;
  final ValueChanged<bool>? onPreserveHdrChanged;
  final ValueChanged<bool>? onVideoPreserveMetadataChanged;
  final ValueChanged<ImageProcessingConfig>? onImageConfigChanged;
  final ValueChanged<AudioProcessingConfig>? onAudioConfigChanged;
  final ValueChanged<int?>? onThreadLimitChanged;
  final void Function(OutputLocationMode mode, String directory)?
  onOutputLocationChanged;
  final ValueChanged<TwoPassMode>? onTwoPassModeChanged;
  final ValueChanged<int?>? onSelectedAudioStreamIndexChanged;

  static const _recommendedPresets = [
    WorkbenchCompressionPreset(
      smartPreset: SmartCompressionPreset.balanced,
      qualityIndex: 4,
      outputFormat: OutputFormat.mp4,
      videoCodec: VideoCodec.h264,
    ),
    WorkbenchCompressionPreset(
      smartPreset: SmartCompressionPreset.chat,
      qualityIndex: 6,
      outputFormat: OutputFormat.mp4,
      videoCodec: VideoCodec.h264,
    ),
    WorkbenchCompressionPreset(
      smartPreset: SmartCompressionPreset.clear,
      qualityIndex: 3,
      outputFormat: OutputFormat.mp4,
      videoCodec: VideoCodec.h264,
    ),
    WorkbenchCompressionPreset(
      smartPreset: SmartCompressionPreset.compact,
      qualityIndex: 8,
      outputFormat: OutputFormat.mp4,
      videoCodec: VideoCodec.hevc,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isVideoTask = task.mediaKind == MediaKind.video;
    final videoConfig =
        selectedVideoConfig ?? task.config.video ?? VideoProcessingConfig.initial();
    final preserveHdr =
        videoConfig.hdrOutputMode == HdrOutputMode.preserveHdr &&
        task.analysisResult?.isHdr == true;
    final modified = _isModified();
    final compressed =
        isVideoTask && _isSourceAlreadyCompressed();

    // ---- build primaryContent ----
    Widget primaryContent;

    if (isVideoTask && selectedPurpose == TaskPurpose.compression) {
      primaryContent = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WorkbenchCompressionOptionsSection(
            mode: selectedCompressionMode,
            presets: _recommendedPresets,
            selectedQualityIndex: selectedQualityIndex,
            activePresetTitle: _presetForSmartPreset(selectedSmartPreset).title,
            selectedTargetSizeRatio: selectedTargetSizeRatio,
            estimatedSizeForPreset: (_) => '',
            targetSizeModeEnabled:
                !preserveHdr &&
                VideoOutputCompatibility.supportsTargetSize(
                  selectedVideoCodec,
                ),
            isPresetEnabled: (_) => !preserveHdr,
            onModeChanged: onCompressionModeChanged,
            onPresetSelected: (preset) {
              onCompressionModeChanged(CompressionMode.preset);
              onSmartPresetChanged(preset.smartPreset);
              onQualityChanged(preset.qualityIndex);
              onOutputFormatChanged(preset.outputFormat);
              onVideoCodecChanged(preset.videoCodec);
              onEncoderBackendChanged(EncoderBackend.auto);
            },
            onTargetSizeRatioChanged: onTargetSizeRatioChanged,
          ),
          const SizedBox(height: 14),
          _buildMediaConfigPanel(),
        ],
      );
    } else {
      primaryContent = _buildMediaConfigPanel();
    }

    // ---- build advancedContent ----
    final audioStreams = task.analysisResult?.audioStreams ?? const [];
    final advancedContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selectedPurpose == TaskPurpose.conversion)
          ConfigCheckbox(
            label: '保留元数据',
            value: _preserveMetadata(),
            height: 40,
            fontSize: 12,
            onChanged: _onPreserveMetadataChanged,
          ),
        if (task.mediaKind == MediaKind.video &&
            selectedPurpose == TaskPurpose.compression) ...[
          ConfigDropdown<TwoPassMode>(
            label: '两遍压缩',
            trailingText: '',
            value: videoConfig.twoPassMode,
            values: TwoPassMode.values,
            itemLabel: (mode) => switch (mode) {
              TwoPassMode.automatic => '自动',
              TwoPassMode.enabled => '开启',
              TwoPassMode.disabled => '关闭',
            },
            onChanged: (value) {
              if (value != null) {
                onTwoPassModeChanged?.call(value);
              }
            },
            height: 40,
            showTrailingText: false,
            labelFontSize: 12,
            valueFontSize: 12,
          ),
          if (audioStreams.isNotEmpty) ...[
            const SizedBox(height: 12),
            ConfigDropdown<int>(
              label: '音频流',
              trailingText: '',
              value: videoConfig.selectedAudioStreamIndex ?? -1,
              values: [
                -1,
                ...audioStreams.map((stream) => stream.index),
              ],
              itemLabel: (value) {
                if (value == -1) return '自动';
                final stream = audioStreams.firstWhere(
                  (stream) => stream.index == value,
                  orElse: () => audioStreams.first,
                );
                return stream.displayLabel;
              },
              onChanged: (value) {
                if (value != null) {
                  onSelectedAudioStreamIndexChanged
                      ?.call(value == -1 ? null : value);
                }
              },
              height: 40,
              showTrailingText: false,
              labelFontSize: 12,
              valueFontSize: 12,
            ),
          ],
        ],
      ],
    );

    return TaskConfigDialogTemplate(
      task: task,
      title: title,
      onClose: onClose,
      onSave: onSave,
      onOpenSource: onOpenSource,
      thumbnail: thumbnail,
      sourceSummary: sourceSummary,
      selectedPurpose: selectedPurpose,
      onPurposeChanged: onPurposeChanged ?? (_) {},
      primaryContent: primaryContent,
      threadLimit: selectedConfig?.threadLimit ?? task.config.threadLimit,
      onThreadLimitChanged: onThreadLimitChanged ?? (_) {},
      advancedContent: advancedContent,
      modified: modified,
      compressed: compressed,
    );
  }

  Widget _buildMediaConfigPanel() {
    if (selectedPurpose == TaskPurpose.conversion) {
      switch (task.mediaKind) {
        case MediaKind.video:
          return WorkbenchConversionFormatPanel<OutputFormat>(
            label: '目标格式',
            value: selectedOutputFormat,
            values: OutputFormat.values,
            itemLabel: (value) => value.label,
            onChanged: onOutputFormatChanged,
          );
        case MediaKind.image:
          final imageConfig =
              selectedImageConfig ??
              task.config.image ??
              ImageProcessingConfig.initial();
          return WorkbenchConversionFormatPanel<MediaOutputFormat>(
            label: '目标格式',
            value: imageConfig.outputFormat,
            values: MediaOutputFormat.formatsFor(MediaKind.image),
            itemLabel: (value) => value.label,
            onChanged: (value) {
              onImageConfigChanged?.call(
                imageConfig.copyWith(
                  outputFormat: value,
                  keepOriginalOutputFormat: false,
                  losslessCompression: false,
                  imageQuality: 100,
                  resizePreset: ImageResizePreset.original,
                ),
              );
            },
          );
        case MediaKind.audio:
          final audioConfig =
              selectedAudioConfig ??
              task.config.audio ??
              AudioProcessingConfig.initial();
          return WorkbenchConversionFormatPanel<MediaOutputFormat>(
            label: '目标格式',
            value: audioConfig.outputFormat,
            values: MediaOutputFormat.formatsFor(MediaKind.audio),
            itemLabel: (value) => value.label,
            onChanged: (value) {
              onAudioConfigChanged?.call(
                audioConfig.copyWith(
                  outputFormat: value,
                  keepOriginalOutputFormat: false,
                  bitratePreset: AudioBitratePreset.source,
                  sampleRate: AudioSampleRatePreset.source,
                  channels: AudioChannelsPreset.source,
                ),
              );
            },
          );
      }
    }

    switch (task.mediaKind) {
      case MediaKind.video:
        final videoConfig =
            selectedVideoConfig ??
            task.config.video ??
            VideoProcessingConfig.initial();
        final preserveHdr =
            videoConfig.hdrOutputMode == HdrOutputMode.preserveHdr &&
            task.analysisResult?.isHdr == true;
        return WorkbenchVideoConfigPanel(
          selectedOutputFormat: selectedOutputFormat,
          selectedVideoCodec:
              preserveHdr ? VideoCodec.hevc : selectedVideoCodec,
          selectedEncoderBackend: selectedEncoderBackend,
          selectedResolutionPreset: selectedResolutionPreset,
          availableEncoderBackends: availableEncoderBackends,
          onOutputFormatChanged: onOutputFormatChanged,
          onVideoCodecChanged: onVideoCodecChanged,
          onEncoderBackendChanged: onEncoderBackendChanged,
          onResolutionPresetChanged: onResolutionPresetChanged,
          sourceOutputFormat: null,
          keepOriginalOutputFormat: videoConfig.keepOriginalOutputFormat,
          showPreserveHdrOption: task.analysisResult?.isHdr == true,
          preserveHdr: preserveHdr,
          onPreserveHdrChanged: onPreserveHdrChanged,
          preserveMetadata: videoConfig.preserveMetadata,
          onPreserveMetadataChanged: onVideoPreserveMetadataChanged,
          videoCodecValues: preserveHdr
              ? const [VideoCodec.hevc]
              : VideoOutputCompatibility.codecsFor(selectedOutputFormat),
          videoCodecEnabled: !preserveHdr,
          showEncoderBackend: false,
          resolutionValues: const [
            ResolutionPreset.original,
            ResolutionPreset.p2160,
            ResolutionPreset.p1080,
            ResolutionPreset.p720,
            ResolutionPreset.p480,
          ],
          padding: EdgeInsets.zero,
          itemSpacing: 8,
          dropdownHeight: 40,
          showTrailingText: false,
          resolutionLabelBuilder: (v) => v.label,
          labelFontSize: 12,
          valueFontSize: 12,
        );
      case MediaKind.image:
        final imageConfig =
            selectedImageConfig ??
            task.config.image ??
            ImageProcessingConfig.initial();
        return WorkbenchImageConfigPanel(
          config: imageConfig,
          onChanged: onImageConfigChanged ?? (_) {},
          showLosslessCompression: selectedPurpose == TaskPurpose.compression,
          sourceOutputFormat: null,
          sourceWidth:
              task.analysisResult?.imageWidth ??
              task.analysisResult?.videoWidth,
          sourceHeight:
              task.analysisResult?.imageHeight ??
              task.analysisResult?.videoHeight,
          padding: EdgeInsets.zero,
          itemSpacing: 8,
          dropdownHeight: 40,
          showTrailingText: false,
          labelFontSize: 12,
          valueFontSize: 12,
        );
      case MediaKind.audio:
        final audioConfig =
            selectedAudioConfig ??
            task.config.audio ??
            AudioProcessingConfig.initial();
        return WorkbenchAudioConfigPanel(
          config: audioConfig,
          onChanged: onAudioConfigChanged ?? (_) {},
          sourceOutputFormat: null,
          padding: EdgeInsets.zero,
          itemSpacing: 8,
          dropdownHeight: 40,
          showTrailingText: false,
          labelFontSize: 12,
          valueFontSize: 12,
        );
    }
  }

  WorkbenchCompressionPreset _presetForSmartPreset(
    SmartCompressionPreset smartPreset,
  ) {
    for (final preset in _recommendedPresets) {
      if (preset.smartPreset == smartPreset) return preset;
    }
    return _recommendedPresets.first;
  }

  bool _isSourceAlreadyCompressed() {
    if (task.mediaKind != MediaKind.video) return false;
    final codec = task.analysisResult?.videoCodec?.toLowerCase() ?? '';
    return codec == 'hevc' || codec == 'h265' || codec == 'vp9' || codec == 'av1';
  }

  bool _preserveMetadata() {
    return switch (task.mediaKind) {
      MediaKind.video =>
        (selectedVideoConfig ?? task.config.video)?.preserveMetadata ?? true,
      MediaKind.image =>
        (selectedImageConfig ?? task.config.image)?.preserveMetadata ?? true,
      MediaKind.audio =>
        (selectedAudioConfig ?? task.config.audio)?.preserveMetadata ?? true,
    };
  }

  void _onPreserveMetadataChanged(bool value) {
    switch (task.mediaKind) {
      case MediaKind.video:
        onVideoPreserveMetadataChanged?.call(value);
      case MediaKind.image:
        final config =
            selectedImageConfig ??
            task.config.image ??
            ImageProcessingConfig.initial();
        onImageConfigChanged?.call(config.copyWith(preserveMetadata: value));
      case MediaKind.audio:
        final config =
            selectedAudioConfig ??
            task.config.audio ??
            AudioProcessingConfig.initial();
        onAudioConfigChanged?.call(config.copyWith(preserveMetadata: value));
    }
  }

  bool _isModified() {
    if (task.purpose != selectedPurpose) return true;
    final config = selectedConfig ?? task.config;
    if (task.config.threadLimit != config.threadLimit) return true;
    return false;
  }
}

Future<void> _pumpTaskConfigurationDialog(
  WidgetTester tester, {
  MediaTask? task,
  int selectedQualityIndex = 4,
  OutputFormat selectedOutputFormat = OutputFormat.mp4,
  VideoCodec selectedVideoCodec = VideoCodec.h264,
  EncoderBackend selectedEncoderBackend = EncoderBackend.auto,
  ResolutionPreset selectedResolutionPreset = ResolutionPreset.original,
  CompressionMode selectedCompressionMode = CompressionMode.preset,
  SmartCompressionPreset selectedSmartPreset = SmartCompressionPreset.balanced,
  double selectedTargetSizeRatio = 0.6,
  TaskPurpose selectedPurpose = TaskPurpose.compression,
  List<EncoderBackend> availableEncoderBackends = const [EncoderBackend.auto],
  Widget? sourceSummary,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: _TestTaskConfigDialog(
          task: task ?? testTask(),
          thumbnail: null,
          sourceSummary: sourceSummary,
          selectedQualityIndex: selectedQualityIndex,
          selectedOutputFormat: selectedOutputFormat,
          selectedVideoCodec: selectedVideoCodec,
          selectedEncoderBackend: selectedEncoderBackend,
          selectedResolutionPreset: selectedResolutionPreset,
          selectedCompressionMode: selectedCompressionMode,
          selectedSmartPreset: selectedSmartPreset,
          selectedTargetSizeRatio: selectedTargetSizeRatio,
          selectedPurpose: selectedPurpose,
          availableEncoderBackends: availableEncoderBackends,
          onClose: () {},
          onOpenSource: () {},
          onSave: () {},
          onCompressionModeChanged: (_) {},
          onSmartPresetChanged: (_) {},
          onTargetSizeRatioChanged: (_) {},
          onQualityChanged: (_) {},
          onOutputFormatChanged: (_) {},
          onVideoCodecChanged: (_) {},
          onEncoderBackendChanged: (_) {},
          onResolutionPresetChanged: (_) {},
        ),
      ),
    ),
  );
}

MediaTask testTask({
  String fileName = 'source.mp4',
  VideoTaskConfig? config,
  TaskStatus? status,
  MediaAnalysisResult? analysisResult,
  bool hasAnalysisResult = true,
}) {
  return MediaTask(
    id: 'task-1',
    inputPath: '/videos/$fileName',
    fileName: fileName,
    mediaKind: MediaKind.video,
    purpose: TaskPurpose.compression,
    status: status ?? TaskStatus.pending,
    config: config ?? VideoTaskConfig.initial(),
    progress: 0,
    sortOrder: 0,
    createdAt: 1,
    sourceFileFingerprint: const SourceFileFingerprint(
      fileSize: 100 * 1024 * 1024,
      lastModifiedAt: 1,
    ),
    analysisResult: hasAnalysisResult
        ? analysisResult ??
              MediaAnalysisResult(
                durationMs: 60000,
                videoWidth: 3840,
                videoHeight: 2160,
                videoCodec: 'h264',
                videoBitrate: 12000000,
                audioBitrate: 128000,
              )
        : null,
  );
}

MediaTask imageTask({ImageProcessingConfig? config}) {
  return MediaTask(
    id: 'image-task',
    inputPath: '/images/source.png',
    fileName: 'source.png',
    mediaKind: MediaKind.image,
    purpose: TaskPurpose.compression,
    status: TaskStatus.pending,
    config: MediaTaskConfig.initialImage().copyWith(
      image: config ?? ImageProcessingConfig.initial(),
    ),
    progress: 0,
    sortOrder: 0,
    createdAt: 1,
    sourceFileFingerprint: const SourceFileFingerprint(
      fileSize: 2 * 1024 * 1024,
      lastModifiedAt: 1,
    ),
    analysisResult: MediaAnalysisResult(
      imageWidth: 1200,
      imageHeight: 800,
      imageCodec: 'png',
      imagePixelFormat: 'rgba',
      imageBitDepth: 8,
      containerFormat: 'png_pipe',
    ),
  );
}

MediaTask audioTask({AudioProcessingConfig? config}) {
  return MediaTask(
    id: 'audio-task',
    inputPath: '/audio/source.wav',
    fileName: 'source.wav',
    mediaKind: MediaKind.audio,
    purpose: TaskPurpose.compression,
    status: TaskStatus.pending,
    config: MediaTaskConfig.initialAudio().copyWith(
      audio: config ?? AudioProcessingConfig.initial(),
    ),
    progress: 0,
    sortOrder: 0,
    createdAt: 1,
    sourceFileFingerprint: const SourceFileFingerprint(
      fileSize: 6 * 1024 * 1024,
      lastModifiedAt: 1,
    ),
    analysisResult: MediaAnalysisResult(
      durationMs: 42000,
      audioCodec: 'pcm_s16le',
      audioBitrate: 1411200,
      audioChannels: 2,
      audioSampleRate: 44100,
      containerFormat: 'wav',
    ),
  );
}
