import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/app/presentation/app_layout_constants.dart';
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
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/audio_processing_config.dart';
import 'package:framelean/domain/value_objects/image_processing_config.dart';
import 'package:framelean/domain/value_objects/media_analysis_result.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/domain/value_objects/source_file_fingerprint.dart';
import 'package:framelean/domain/value_objects/video_processing_config.dart';
import 'package:framelean/domain/value_objects/video_task_config.dart';
import 'package:framelean/features/workbench/pages/workbench_page.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/restart_unelevated_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task_completed_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task_configuration_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task_configuration_dialog_widgets.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/workbench_dialog_widgets.dart';
import 'package:framelean/features/workbench/pages/workbench_page/layout/workbench_shell.dart';
import 'package:framelean/features/workbench/pages/workbench_page/layout/top_bar.dart';
import 'package:framelean/app/widgets/form_controls/config_dropdown.dart';
import 'package:framelean/features/workbench/widgets/media_task_list/media_task_list_tile.dart';
import 'package:framelean/features/workbench/widgets/media_task_list/task_folder_content_panel.dart';
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
          body: WorkbenchTaskConfigurationDialog(
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
    final videoConfig = VideoProcessingConfig.initial().copyWith(
      videoCodec: VideoCodec.hevc,
      hdrOutputMode: HdrOutputMode.preserveHdr,
      smartPreset: SmartCompressionPreset.clear,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkbenchTaskConfigurationDialog(
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
          ),
        ),
      ),
    );

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
        of: find.byType(WorkbenchDialogActions),
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
          body: WorkbenchTaskConfigurationDialog(
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
          body: WorkbenchTaskConfigurationDialog(
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
          body: WorkbenchTaskConfigurationDialog(
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
    expect(find.text('保留80%的质量'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('图片编码'), findsNothing);
    expect(find.text('尺寸'), findsNothing);
    expect(find.text('保留元数据'), findsOneWidget);
    expect(find.text('视频编码'), findsNothing);
    expect(
      tester.getCenter(find.byType(Switch)).dx,
      lessThan(tester.getCenter(find.text('保留元数据')).dx),
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

    final metadataSwitch = tester.widget<Switch>(find.byType(Switch));
    metadataSwitch.onChanged?.call(true);

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
      imageChanges.map((config) => config.preserveMetadata),
      contains(true),
    );
  });

  testWidgets('audio task configuration exposes audio controls', (
    tester,
  ) async {
    final audioChanges = <AudioProcessingConfig>[];
    final initialConfig = AudioProcessingConfig.initial();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkbenchTaskConfigurationDialog(
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
  });

  testWidgets('already compressed source shows no estimated size text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkbenchTaskConfigurationDialog(
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
        of: find.byType(WorkbenchDialogActions),
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
          body: WorkbenchTaskConfigurationDialog(
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

  testWidgets('completed dialog focuses on size and output path', (
    tester,
  ) async {
    final outputPath =
        '/exports/a/very/long/path/that/should/scroll/in/a/single/line/result.mp4';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskCompletedDialog(
            outputPath: outputPath,
            sourceFileSize: 100 * 1024 * 1024,
            outputFileSize: 25 * 1024 * 1024,
            onClose: () {},
            onReveal: () {},
          ),
        ),
      ),
    );

    expect(find.text('处理完成'), findsOneWidget);
    expect(find.text('源文件'), findsOneWidget);
    expect(find.text('100MB'), findsOneWidget);
    expect(find.text('输出文件'), findsOneWidget);
    expect(find.text('25MB'), findsOneWidget);
    expect(find.text('导出位置'), findsOneWidget);
    expect(find.text(outputPath), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('打开文件存放位置'), findsOneWidget);
    expect(find.text('重来'), findsNothing);
    expect(find.text('知道了'), findsNothing);

    final pathScroll = tester.widget<SingleChildScrollView>(
      find.ancestor(
        of: find.text(outputPath),
        matching: find.byType(SingleChildScrollView),
      ),
    );
    expect(pathScroll.scrollDirection, Axis.horizontal);
  });

  testWidgets('restart unelevated dialog warns about active tasks', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RestartUnelevatedDialog())),
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
              selectedTask: null,
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
              onContextMenu: (_, _) {},
              onToggleSelectionMode: () {},
              onToggleTaskSelection: (_) {},
              onSelectTasksWithRectangle: (_) {},
              onCreateFolderFromSelection: () {},
              onMoveTaskToFolder: (_, _) {},
              onRejectTaskFolderDrop: (_, _) {},
              onOpenFolderSettings: (_) {},
              onOpenFolderContents: (_) {},
              onStartFolder: (_) {},
              onPauseFolder: (_) {},
              onRetryFolder: (_) {},
              onRelinkFolder: (_) {},
              onShowFolderLog: (_) {},
              onDeleteFolder: (_) {},
              onAddTask: () {},
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
        greaterThanOrEqualTo(AppLayoutConstants.topBarHeight + 30),
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
            selectedTask: null,
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
            onContextMenu: (_, _) {},
            onToggleSelectionMode: () {},
            onToggleTaskSelection: (_) {},
            onSelectTasksWithRectangle: (_) {},
            onCreateFolderFromSelection: () {},
            onMoveTaskToFolder: (_, _) {},
            onRejectTaskFolderDrop: (_, _) {},
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
            onAddTask: () {},
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
                onRemoveTask: (_) {
                  removeCount += 1;
                },
                onStart: (_) {
                  startCount += 1;
                },
                onPause: (_) {},
                onRetry: (_) {},
                onRelink: (_) {},
                onShowLog: (_) {},
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
            selectedTask: null,
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
            onContextMenu: (_, _) {},
            onToggleSelectionMode: () {
              toggleModeCount += 1;
            },
            onToggleTaskSelection: (_) {},
            onSelectTasksWithRectangle: (_) {},
            onCreateFolderFromSelection: () {
              createFolderCount += 1;
            },
            onMoveTaskToFolder: (_, _) {},
            onRejectTaskFolderDrop: (_, _) {},
            onOpenFolderSettings: (_) {},
            onOpenFolderContents: (_) {},
            onStartFolder: (_) {},
            onPauseFolder: (_) {},
            onRetryFolder: (_) {},
            onRelinkFolder: (_) {},
            onShowFolderLog: (_) {},
            onDeleteFolder: (_) {},
            onAddTask: () {},
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
    expect(find.text('创建任务夹 1'), findsOneWidget);

    await tester.tap(find.byTooltip('退出多选'));
    await tester.pump();
    expect(toggleModeCount, 1);

    await tester.tap(find.text('创建任务夹 1'));
    await tester.pump();
    expect(createFolderCount, 1);
  });

  testWidgets('dragging a loose task into matching folder triggers move', (
    tester,
  ) async {
    final moveCalls = <String>[];
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
            selectedTask: null,
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
            onContextMenu: (_, _) {},
            onToggleSelectionMode: () {},
            onToggleTaskSelection: (_) {},
            onSelectTasksWithRectangle: (_) {},
            onCreateFolderFromSelection: () {},
            onMoveTaskToFolder: (task, folder) {
              moveCalls.add('${task.id}->${folder.id}');
            },
            onRejectTaskFolderDrop: (_, _) {},
            onOpenFolderSettings: (_) {},
            onOpenFolderContents: (_) {},
            onStartFolder: (_) {},
            onPauseFolder: (_) {},
            onRetryFolder: (_) {},
            onRelinkFolder: (_) {},
            onShowFolderLog: (_) {},
            onDeleteFolder: (_) {},
            onAddTask: () {},
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

    final dragHandle = find.byIcon(Icons.drag_indicator_rounded).first;
    final target = find.text('视频任务夹（1）');
    await tester.dragFrom(
      tester.getCenter(dragHandle),
      tester.getCenter(target) - tester.getCenter(dragHandle),
    );
    await tester.pumpAndSettle();

    expect(moveCalls, ['outside->folder-1']);
  });

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
            selectedTask: firstTask,
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
            onContextMenu: (_, _) {},
            onToggleSelectionMode: () {},
            onToggleTaskSelection: (_) {},
            onSelectTasksWithRectangle: (_) {},
            onCreateFolderFromSelection: () {},
            onMoveTaskToFolder: (_, _) {},
            onRejectTaskFolderDrop: (_, _) {},
            onOpenFolderSettings: (_) {},
            onOpenFolderContents: (_) {},
            onStartFolder: (_) {},
            onPauseFolder: (_) {},
            onRetryFolder: (_) {},
            onRelinkFolder: (_) {},
            onShowFolderLog: (_) {},
            onDeleteFolder: (_) {},
            onAddTask: () {},
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
  List<EncoderBackend> availableEncoderBackends = const [EncoderBackend.auto],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: WorkbenchTaskConfigurationDialog(
          task: task ?? testTask(),
          thumbnail: null,
          selectedQualityIndex: selectedQualityIndex,
          selectedOutputFormat: selectedOutputFormat,
          selectedVideoCodec: selectedVideoCodec,
          selectedEncoderBackend: selectedEncoderBackend,
          selectedResolutionPreset: selectedResolutionPreset,
          selectedCompressionMode: selectedCompressionMode,
          selectedSmartPreset: selectedSmartPreset,
          selectedTargetSizeRatio: selectedTargetSizeRatio,
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
