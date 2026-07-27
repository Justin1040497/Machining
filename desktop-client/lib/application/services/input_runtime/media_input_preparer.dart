import 'package:framelean/domain/library.dart';

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

/// 在提交 FEngine 分析或执行前准备实际输入文件。
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
