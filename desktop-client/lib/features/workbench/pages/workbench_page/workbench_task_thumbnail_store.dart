import 'dart:io';

import 'package:flutter/material.dart';
import 'package:framelean/application/services/engine/engine_gateway.dart';
import 'package:framelean/domain/library.dart';
import 'package:path/path.dart' as path;

class WorkbenchTaskThumbnailStore {
  final Map<String, String> _videoThumbnailPaths = <String, String>{};
  final Set<String> _pendingTaskIds = <String>{};

  ImageProvider? imageForTask(MediaTask task) {
    if (task.mediaKind == MediaKind.image &&
        File(task.inputPath).existsSync()) {
      return FileImage(File(task.inputPath));
    }
    final thumbnailPath = _videoThumbnailPaths[task.id];
    return thumbnailPath == null ? null : FileImage(File(thumbnailPath));
  }

  Future<void> ensureVideoThumbnail({
    required MediaTask task,
    required EngineMediaGateway gateway,
    required VoidCallback onReady,
  }) async {
    if (task.mediaKind != MediaKind.video ||
        _videoThumbnailPaths.containsKey(task.id) ||
        !_pendingTaskIds.add(task.id)) {
      return;
    }
    final fingerprint = task.sourceFileFingerprint;
    final durationMs = task.analysisResult?.durationMs;
    if (fingerprint == null || durationMs == null || durationMs <= 0) {
      _pendingTaskIds.remove(task.id);
      return;
    }
    final outputPath = path.join(
      Directory.systemTemp.path,
      'framelean/thumbnails',
      '${task.id}.bmp',
    );
    try {
      final result = await gateway.generateVideoThumbnail(
        EngineVideoThumbnailRequest(
          clientTaskId: task.id,
          source: EngineSourceFacts(
            path: task.inputPath,
            fileSizeBytes: fingerprint.fileSize,
            modifiedTimeUnixNanos: null,
          ),
          outputPath: outputPath,
          durationUs: durationMs * Duration.microsecondsPerMillisecond,
          maxWidth: 80,
        ),
      );
      if (File(result.value.outputPath).existsSync()) {
        _videoThumbnailPaths[task.id] = result.value.outputPath;
        onReady();
      }
    } on Object {
      // A thumbnail is an optional visual aid. Its failure must not change a
      // task's analysis or execution state.
    } finally {
      _pendingTaskIds.remove(task.id);
    }
  }
}
