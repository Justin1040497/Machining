import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/compression_mode.dart';
import 'package:framelean/domain/enums/encoder_backend.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/output_format.dart';
import 'package:framelean/domain/enums/resolution_preset.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/media_analysis_result.dart';
import 'package:framelean/domain/value_objects/source_file_fingerprint.dart';
import 'package:framelean/domain/value_objects/video_task_config.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_constants.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/restart_unelevated_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task_completed_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/task_configuration_dialog.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/workbench_dialog_widgets.dart';
import 'package:framelean/features/workbench/pages/workbench_page/layout/workbench_shell.dart';
import 'package:framelean/features/workbench/widgets/media_task_list/media_task_list_tile.dart';

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
    expect(find.text('60%'), findsWidgets);

    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged?.call(8);

    expect(ratioChanges, [0.9]);
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

    expect(find.text('压缩完成'), findsOneWidget);
    expect(find.text('压缩前'), findsOneWidget);
    expect(find.text('100MB'), findsOneWidget);
    expect(find.text('压缩后'), findsOneWidget);
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
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkbenchShell(
              taskList: AsyncData([testTask()]),
              selectedTask: null,
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
              onAddTask: () {},
              onOpenSettings: () {},
              onClearTasks: () {},
              onPrimaryQueuePressed: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('windows-notice-safe-area')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(MediaTaskListTile)).dy,
        greaterThanOrEqualTo(WorkbenchConstants.appTopBarHeight + 30),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
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
