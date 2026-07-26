import 'package:framelean/application/models/engine_analysis_documents.dart';
import 'package:framelean/domain/library.dart';

EngineTaskMode engineTaskModeForMediaTask(MediaTask task) {
  return switch ((task.mediaKind, task.purpose)) {
    (MediaKind.video, TaskPurpose.compression) => EngineTaskMode.videoCompress,
    (MediaKind.video, TaskPurpose.conversion) => EngineTaskMode.videoConvert,
    (MediaKind.audio, TaskPurpose.compression) => EngineTaskMode.audioCompress,
    (MediaKind.audio, TaskPurpose.conversion) => EngineTaskMode.audioConvert,
    (MediaKind.image, TaskPurpose.compression) => EngineTaskMode.imageCompress,
    (MediaKind.image, TaskPurpose.conversion) => EngineTaskMode.imageConvert,
  };
}
