import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:framelean/application/services/app_notifications/task_completion_sound_player.dart';
import 'package:framelean/domain/enums/task_completion_sound.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

typedef TaskCompletionSoundProcessStarter =
    Future<Process> Function(String executable, List<String> arguments);

class LocalTaskCompletionSoundPlayer implements TaskCompletionSoundPlayer {
  LocalTaskCompletionSoundPlayer({
    AssetBundle? assetBundle,
    Future<Directory> Function()? loadTemporaryDirectory,
    TaskCompletionSoundProcessStarter? startProcess,
    bool? isMacOS,
    bool? isWindows,
  }) : _assetBundle = assetBundle ?? rootBundle,
       _getTemporaryDirectory = loadTemporaryDirectory ?? getTemporaryDirectory,
       _startProcess = startProcess ?? _startDetachedProcess,
       _isMacOS = isMacOS ?? Platform.isMacOS,
       _isWindows = isWindows ?? Platform.isWindows;

  final AssetBundle _assetBundle;
  final Future<Directory> Function() _getTemporaryDirectory;
  final TaskCompletionSoundProcessStarter _startProcess;
  final bool _isMacOS;
  final bool _isWindows;

  @override
  Future<void> play(TaskCompletionSound sound) async {
    final assetPath = taskCompletionSoundAssetPath(sound);
    if (assetPath == null) {
      return;
    }

    try {
      final filePath = await _materializeAsset(assetPath);
      await _playFile(filePath);
    } on Object {
      // Audio feedback should never block or fail the task notification path.
    }
  }

  Future<String> _materializeAsset(String assetPath) async {
    final data = await _assetBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    final tempDirectory = await _getTemporaryDirectory();
    final soundsDirectory = Directory(
      path.join(tempDirectory.path, 'framelean', 'sounds'),
    );
    await soundsDirectory.create(recursive: true);

    final file = File(
      path.join(soundsDirectory.path, path.basename(assetPath)),
    );
    await file.writeAsBytes(bytes, flush: false);
    return file.path;
  }

  Future<void> _playFile(String filePath) async {
    if (_isMacOS) {
      await _startProcess('afplay', [filePath]);
      return;
    }

    if (_isWindows) {
      final escapedPath = filePath.replaceAll("'", "''");
      await _startProcess('powershell.exe', [
        '-NoProfile',
        '-NonInteractive',
        '-WindowStyle',
        'Hidden',
        '-Command',
        "\$player = New-Object System.Media.SoundPlayer '$escapedPath'; "
            r'$player.PlaySync()',
      ]);
    }
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

Future<Process> _startDetachedProcess(
  String executable,
  List<String> arguments,
) {
  return Process.start(executable, arguments, mode: ProcessStartMode.detached);
}
