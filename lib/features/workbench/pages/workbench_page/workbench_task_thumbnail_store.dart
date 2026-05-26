import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/services/execution/video_thumbnail_generator.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/infrastructure/providers/execution_provider.dart';
import 'package:framelean/infrastructure/providers/input_runtime_provider.dart';
import 'package:path/path.dart' as path;

class WorkbenchTaskThumbnailStore {
  final Map<String, String> _thumbnailPathByKey = {};
  final Set<String> _generationKeys = {};
  final Set<String> _failureKeys = {};

  ImageProvider? imageForTask(MediaTask task) {
    final thumbnailPath = _thumbnailPathByKey[_keyForTask(task)];
    if (thumbnailPath == null || !File(thumbnailPath).existsSync()) {
      return null;
    }

    return FileImage(File(thumbnailPath));
  }

  void scheduleGenerationAfterBuild({
    required Iterable<MediaTask> tasks,
    required WidgetRef ref,
    required bool Function() isMounted,
    required VoidCallback onChanged,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isMounted()) {
        return;
      }

      for (final task in tasks) {
        unawaited(
          generateForTask(
            task: task,
            ref: ref,
            isMounted: isMounted,
            onChanged: onChanged,
          ),
        );
      }
    });
  }

  Future<void> generateForTask({
    required MediaTask task,
    required WidgetRef ref,
    required bool Function() isMounted,
    required VoidCallback onChanged,
  }) async {
    final key = _keyForTask(task);
    if (_thumbnailPathByKey.containsKey(key) ||
        _generationKeys.contains(key) ||
        _failureKeys.contains(key)) {
      return;
    }

    _generationKeys.add(key);
    try {
      final runtime = await ref.read(ffmpegRuntimeProvider.future);
      final ffmpeg = runtime.ffmpeg;
      if (ffmpeg == null) {
        return;
      }

      final directory = Directory(
        path.join(Directory.systemTemp.path, 'framelean', 'thumbnails'),
      );
      await directory.create(recursive: true);

      final outputPath = path.join(directory.path, _fileNameForTask(task));
      final outputFile = File(outputPath);
      if (!await outputFile.exists()) {
        await ref
            .read(videoThumbnailGeneratorProvider)
            .generate(
              VideoThumbnailRequest(
                ffmpegPath: ffmpeg.path,
                task: task,
                outputPath: outputPath,
              ),
            );
        if (!await outputFile.exists()) {
          _failureKeys.add(key);
          return;
        }
      }

      if (!isMounted()) {
        return;
      }

      _thumbnailPathByKey[key] = outputPath;
      onChanged();
    } on Object {
      _failureKeys.add(key);
    } finally {
      _generationKeys.remove(key);
    }
  }

  String _keyForTask(MediaTask task) {
    final fingerprint = task.sourceFileFingerprint;
    return [
      task.id,
      task.inputPath,
      fingerprint?.fileSize ?? 0,
      fingerprint?.lastModifiedAt ?? 0,
    ].join('|');
  }

  String _fileNameForTask(MediaTask task) {
    final fingerprint = task.sourceFileFingerprint;
    final name = [
      task.id,
      fingerprint?.fileSize ?? 0,
      fingerprint?.lastModifiedAt ?? 0,
    ].join('_');
    return '$name.jpg';
  }
}
