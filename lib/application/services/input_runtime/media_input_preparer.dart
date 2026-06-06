import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/value_objects/proprietary_audio_decode_result.dart';

enum MediaInputPreparationPurpose { analysis, execution }

class PreparedMediaInput {
  final MediaTask task;
  final ProprietaryAudioDecodeResult? proprietaryAudioDecodeResult;

  const PreparedMediaInput({
    required this.task,
    this.proprietaryAudioDecodeResult,
  });

  bool get usesTemporaryInput {
    return proprietaryAudioDecodeResult != null;
  }
}

/// 在 FFprobe 分析或 FFmpeg 执行前准备实际输入文件。
abstract interface class MediaInputPreparer {
  Future<PreparedMediaInput> prepare(
    MediaTask task, {
    required MediaInputPreparationPurpose purpose,
  });

  Future<void> cleanup(PreparedMediaInput preparedInput);
}

class NoopMediaInputPreparer implements MediaInputPreparer {
  const NoopMediaInputPreparer();

  @override
  Future<PreparedMediaInput> prepare(
    MediaTask task, {
    required MediaInputPreparationPurpose purpose,
  }) async {
    return PreparedMediaInput(task: task);
  }

  @override
  Future<void> cleanup(PreparedMediaInput preparedInput) async {}
}
