import 'package:machining/domain/entities/media_task.dart';

class VideoThumbnailRequest {
  final String ffmpegPath;
  final MediaTask task;
  final String outputPath;

  const VideoThumbnailRequest({
    required this.ffmpegPath,
    required this.task,
    required this.outputPath,
  });
}

class VideoThumbnailResult {
  final String outputPath;
  final double timestampSeconds;

  const VideoThumbnailResult({
    required this.outputPath,
    required this.timestampSeconds,
  });
}

class VideoThumbnailGenerationException implements Exception {
  final String message;

  const VideoThumbnailGenerationException(this.message);

  @override
  String toString() {
    return message;
  }
}

abstract class VideoThumbnailGenerator {
  Future<VideoThumbnailResult> generate(VideoThumbnailRequest request);
}
