import 'package:audioplayers/audioplayers.dart';
import 'package:framelean/application/services/app_notifications/task_completion_sound_player.dart';
import 'package:framelean/domain/enums/task_completion_sound.dart';

typedef TaskCompletionSoundAssetPlayer =
    Future<void> Function(String assetPath);

class LocalTaskCompletionSoundPlayer implements TaskCompletionSoundPlayer {
  LocalTaskCompletionSoundPlayer({TaskCompletionSoundAssetPlayer? playAsset})
    : _playAsset = playAsset;

  final TaskCompletionSoundAssetPlayer? _playAsset;
  AudioPlayer? _audioPlayer;

  @override
  Future<void> play(TaskCompletionSound sound) async {
    final assetPath = taskCompletionSoundAssetPath(sound);
    if (assetPath == null) {
      return;
    }

    try {
      final player = _playAsset ?? _playAssetWithAudioPlayer;
      await player(taskCompletionSoundAudioplayersAssetPath(assetPath));
    } on Object {
      // Audio feedback should never block or fail the task notification path.
    }
  }

  Future<void> _playAssetWithAudioPlayer(String assetPath) async {
    final existingPlayer = _audioPlayer;
    if (existingPlayer == null) {
      final player = AudioPlayer();
      _audioPlayer = player;
      await player.play(AssetSource(assetPath));
      return;
    }

    await existingPlayer.stop();
    await existingPlayer.play(AssetSource(assetPath));
  }

  Future<void> dispose() async {
    await _audioPlayer?.dispose();
    _audioPlayer = null;
  }
}

String? taskCompletionSoundAssetPath(TaskCompletionSound sound) {
  return switch (sound) {
    TaskCompletionSound.none => null,
    TaskCompletionSound.cleanSuccess =>
      'assets/sounds/task_complete_clean_success.wav',
    TaskCompletionSound.mechanicalKey =>
      'assets/sounds/task_complete_mechanical_key.wav',
    TaskCompletionSound.originalSoftA =>
      'assets/sounds/task_complete_original_soft_a.wav',
    TaskCompletionSound.originalSoftB =>
      'assets/sounds/task_complete_original_soft_b.wav',
    TaskCompletionSound.servoConfirm =>
      'assets/sounds/task_complete_servo_confirm.wav',
  };
}

String taskCompletionSoundAudioplayersAssetPath(String assetPath) {
  const flutterAssetsPrefix = 'assets/';
  if (assetPath.startsWith(flutterAssetsPrefix)) {
    return assetPath.substring(flutterAssetsPrefix.length);
  }

  return assetPath;
}
