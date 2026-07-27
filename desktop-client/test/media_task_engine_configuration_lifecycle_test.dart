import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/domain/library.dart';

void main() {
  test('replacing a source clears its engine configuration reference', () {
    final task = _task();

    final replaced = task.replaceInputFile(
      newInputPath: '/videos/replacement.mp4',
      newFileName: 'replacement.mp4',
      newMediaKind: MediaKind.video,
    );

    expect(replaced.config.engineConfiguration, isNull);
  });

  test('clearing analysis clears its engine configuration reference', () {
    final task = _task();

    final cleared = task.clearAnalysis();

    expect(cleared.config.engineConfiguration, isNull);
  });
}

MediaTask _task() {
  return MediaTask(
    id: 'task-1',
    inputPath: '/videos/source.mp4',
    fileName: 'source.mp4',
    mediaKind: MediaKind.video,
    purpose: TaskPurpose.compression,
    status: TaskStatus.ready,
    config: MediaTaskConfig.initialVideo().copyWith(
      engineConfiguration: const EngineConfigurationReference(
        analysisId: 'analysis-1',
        analysisRevision: 1,
        candidateId: 'candidate-1',
        selectionMode: 'preset',
        selectionJson:
            '{"mode":"preset","selection":{"preset_id":"balanced","candidate_id":"candidate-1"}}',
      ),
    ),
    progress: 0,
    sortOrder: 0,
  );
}
