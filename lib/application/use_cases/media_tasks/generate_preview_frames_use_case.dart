import 'package:framelean/application/services/execution/preview_frame_generator.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_runtime.dart';
import 'package:framelean/domain/entities/media_task.dart';

class GeneratePreviewFramesException implements Exception {
  final String message;

  const GeneratePreviewFramesException(this.message);

  @override
  String toString() {
    return message;
  }
}

class GeneratePreviewFramesUseCase {
  final Future<ResolvedFfmpegRuntime> Function() readRuntime;
  final PreviewFrameGenerator previewFrameGenerator;

  const GeneratePreviewFramesUseCase({
    required this.readRuntime,
    required this.previewFrameGenerator,
  });

  Future<PreviewFrameResult> call({
    required MediaTask task,
    required bool allowExtremeCompression,
  }) async {
    final durationMs = task.analysisResult?.durationMs;
    if (durationMs == null) {
      throw const GeneratePreviewFramesException('媒体分析完成后才能生成预览');
    }

    final runtime = await readRuntime();
    final ffmpeg = runtime.ffmpeg;
    if (ffmpeg == null) {
      throw const GeneratePreviewFramesException('FFmpeg 不可用，无法生成预览');
    }

    return previewFrameGenerator.generate(
      PreviewFrameRequest(
        ffmpegPath: ffmpeg.path,
        task: task,
        allowExtremeCompression: allowExtremeCompression,
        encoderCapabilities: runtime.encoderCapabilities,
      ),
    );
  }
}
