import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:machining/domain/entities/media_task.dart';
import 'package:machining/domain/enums/compression_mode.dart';
import 'package:machining/domain/enums/encoder_backend.dart';
import 'package:machining/domain/enums/media_kind.dart';
import 'package:machining/domain/enums/output_format.dart';
import 'package:machining/domain/enums/resolution_preset.dart';
import 'package:machining/domain/enums/smart_compression_preset.dart';
import 'package:machining/domain/enums/task_purpose.dart';
import 'package:machining/domain/enums/task_status.dart';
import 'package:machining/domain/enums/video_codec.dart';
import 'package:machining/domain/value_objects/media_analysis_result.dart';
import 'package:machining/domain/value_objects/video_task_config.dart';
import 'package:machining/features/workbench/pages/workbench_page/task_configuration_dialog.dart';

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
            selectedCompressionMode: CompressionMode.smart,
            selectedSmartPreset: SmartCompressionPreset.balanced,
            selectedTargetSizeBytes: null,
            availableEncoderBackends: const [EncoderBackend.auto],
            onClose: () {},
            onOpenSource: () {},
            onSave: () {},
            onCompressionModeChanged: (_) {},
            onSmartPresetChanged: smartPresetChanges.add,
            onTargetSizeBytesChanged: (_) {},
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
}

MediaTask testTask() {
  return MediaTask(
    id: 'task-1',
    inputPath: '/videos/source.mp4',
    fileName: 'source.mp4',
    mediaKind: MediaKind.video,
    purpose: TaskPurpose.compression,
    status: TaskStatus.pending,
    config: VideoTaskConfig.initial(),
    progress: 0,
    sortOrder: 0,
    createdAt: 1,
    analysisResult: MediaAnalysisResult(
      durationMs: 60000,
      videoWidth: 3840,
      videoHeight: 2160,
      videoCodec: 'h264',
      videoBitrate: 12000000,
      audioBitrate: 128000,
    ),
  );
}
