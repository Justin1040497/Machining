import 'package:framelean/domain/enums/task_completion_sound.dart';

abstract interface class TaskCompletionSoundPlayer {
  Future<void> play(TaskCompletionSound sound);
}
