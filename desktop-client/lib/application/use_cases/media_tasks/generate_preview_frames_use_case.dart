import 'dart:io';

import 'package:framelean/application/constants.dart';
import 'package:framelean/application/services/engine/engine_gateway.dart';
import 'package:framelean/application/services/execution/preview_frame_generator.dart';
import 'package:framelean/domain/library.dart';
import 'package:path/path.dart' as path;

class GeneratePreviewFramesException implements Exception {
  final String message;

  const GeneratePreviewFramesException(this.message);

  @override
  String toString() {
    return message;
  }
}

class GeneratePreviewFramesUseCase {
  final Future<EngineGateway> Function() readEngineGateway;

  const GeneratePreviewFramesUseCase({required this.readEngineGateway});

  Future<PreviewFrameResult> call({
    required MediaTask task,
    required bool allowExtremeCompression,
  }) async {
    final durationMs = task.analysisResult?.durationMs;
    final fingerprint = task.sourceFileFingerprint;
    if (durationMs == null || durationMs <= 0 || fingerprint == null) {
      throw const GeneratePreviewFramesException('媒体分析完成后才能生成预览');
    }
    final gateway = await readEngineGateway();
    if (gateway is! EngineMediaGateway) {
      throw const GeneratePreviewFramesException('媒体引擎不支持预览帧服务');
    }
    final directory = path.join(
      Directory.systemTemp.path,
      previewsSubDir,
      task.id,
    );
    final durationUs = durationMs * Duration.microsecondsPerMillisecond;
    const ratios = <double>[0.12, 0.33, 0.5, 0.67, 0.88];
    final response = await gateway.generatePreviewFrames(
      EnginePreviewFramesRequest(
        clientTaskId: task.id,
        source: EngineSourceFacts(
          path: task.inputPath,
          fileSizeBytes: fingerprint.fileSize,
          modifiedTimeUnixNanos: null,
        ),
        outputDirectory: directory,
        timestampsUs: ratios
            .map((ratio) => (durationUs * ratio).round())
            .toList(growable: false),
        maxWidth: 960,
      ),
    );
    final artifacts = response.value.frames;
    if (artifacts.length != ratios.length) {
      throw const GeneratePreviewFramesException('媒体引擎返回的预览帧数量不完整');
    }
    return PreviewFrameResult(
      taskId: task.id,
      directoryPath: response.value.outputDirectory,
      frames: List<PreviewFrameArtifact>.generate(artifacts.length, (index) {
        final frame = artifacts[index];
        return PreviewFrameArtifact(
          index: frame.index,
          ratio: ratios[index],
          timestampSeconds:
              frame.decodedTimestampUs / Duration.microsecondsPerSecond,
          framePath: frame.outputPath,
        );
      }, growable: false),
    );
  }
}
