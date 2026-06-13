import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/domain/enums/task_completion_sound.dart';
import 'package:framelean/infrastructure/services/app_notifications/local_task_completion_sound_player.dart';

void main() {
  test('task completion sounds map to bundled asset paths', () {
    expect(taskCompletionSoundAssetPath(TaskCompletionSound.none), isNull);
    expect(
      taskCompletionSoundAssetPath(TaskCompletionSound.cleanSuccess),
      'assets/sounds/task_complete_clean_success.wav',
    );
    expect(
      taskCompletionSoundAssetPath(TaskCompletionSound.mechanicalKey),
      'assets/sounds/task_complete_mechanical_key.wav',
    );
    expect(
      taskCompletionSoundAssetPath(TaskCompletionSound.originalSoftA),
      'assets/sounds/task_complete_original_soft_a.wav',
    );
    expect(
      taskCompletionSoundAssetPath(TaskCompletionSound.originalSoftB),
      'assets/sounds/task_complete_original_soft_b.wav',
    );
    expect(
      taskCompletionSoundAssetPath(TaskCompletionSound.servoConfirm),
      'assets/sounds/task_complete_servo_confirm.wav',
    );
  });

  test('task completion sounds use audioplayers asset keys', () async {
    final playedAssets = <String>[];
    final player = LocalTaskCompletionSoundPlayer(
      playAsset: (assetPath) async => playedAssets.add(assetPath),
    );

    await player.play(TaskCompletionSound.none);
    await player.play(TaskCompletionSound.servoConfirm);

    expect(playedAssets, ['sounds/task_complete_servo_confirm.wav']);
  });

  test('asset paths remove Flutter assets prefix for audioplayers', () {
    expect(
      taskCompletionSoundAudioplayersAssetPath(
        'assets/sounds/task_complete_clean_success.wav',
      ),
      'sounds/task_complete_clean_success.wav',
    );
    expect(
      taskCompletionSoundAudioplayersAssetPath(
        'sounds/task_complete_clean_success.wav',
      ),
      'sounds/task_complete_clean_success.wav',
    );
  });
}
