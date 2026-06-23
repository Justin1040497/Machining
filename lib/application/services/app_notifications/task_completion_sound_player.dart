import 'package:framelean/domain/library.dart';

abstract interface class TaskCompletionSoundPlayer {
  Future<void> play(TaskCompletionSound sound);
}
