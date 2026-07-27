import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/features/workbench/pages/workbench_page/workbench_task_thumbnail_store.dart';

void main() {
  test(
    'preview use case sends source facts and maps engine artifacts',
    () async {
      final gateway = _FakeEngineMediaGateway();
      final task = _videoTask(id: 'preview-task', durationMs: 10000);

      final result = await GeneratePreviewFramesUseCase(
        readEngineGateway: () async => gateway,
      ).call(task: task);

      final request = gateway.previewRequests.single;
      expect(request.clientTaskId, task.id);
      expect(request.source.path, task.inputPath);
      expect(request.source.fileSizeBytes, 2048);
      expect(request.timestampsUs, <int>[
        1200000,
        3300000,
        5000000,
        6700000,
        8800000,
      ]);
      expect(request.maxWidth, 960);
      expect(result.frames.map((frame) => frame.ratio), <double>[
        0.12,
        0.33,
        0.5,
        0.67,
        0.88,
      ]);
      expect(result.frames.first.timestampSeconds, 1.201);
      expect(result.frames.first.framePath, endsWith('frame-0.bmp'));
    },
  );

  test(
    'thumbnail store deduplicates pending work and caches a valid file',
    () async {
      final gateway = _FakeEngineMediaGateway(pauseThumbnail: true);
      final store = WorkbenchTaskThumbnailStore();
      final task = _videoTask(id: 'thumbnail-task', durationMs: 12000);
      var readyCount = 0;

      final first = store.ensureVideoThumbnail(
        task: task,
        gateway: gateway,
        onReady: () => readyCount += 1,
      );
      await Future<void>.delayed(Duration.zero);
      await store.ensureVideoThumbnail(
        task: task,
        gateway: gateway,
        onReady: () => readyCount += 1,
      );

      expect(gateway.thumbnailRequests, hasLength(1));
      final request = gateway.thumbnailRequests.single;
      expect(request.durationUs, 12000000);
      expect(request.maxWidth, 80);
      gateway.releaseThumbnail();
      await first;

      expect(readyCount, 1);
      expect(store.imageForTask(task), isA<FileImage>());
      await File(request.outputPath).delete();
    },
  );
}

MediaTask _videoTask({required String id, required int durationMs}) {
  return MediaTask(
    id: id,
    inputPath: '/media/input.mp4',
    fileName: 'input.mp4',
    mediaKind: MediaKind.video,
    purpose: TaskPurpose.compression,
    status: TaskStatus.ready,
    config: MediaTaskConfig.initialVideo(),
    progress: 0,
    sortOrder: 0,
    sourceFileFingerprint: const SourceFileFingerprint(
      fileSize: 2048,
      lastModifiedAt: 123,
    ),
    analysisResult: MediaAnalysisResult(durationMs: durationMs),
    analysisUpdatedAt: 1,
    createdAt: 1,
  );
}

class _FakeEngineMediaGateway extends Fake implements EngineMediaGateway {
  _FakeEngineMediaGateway({this.pauseThumbnail = false});

  final bool pauseThumbnail;
  final previewRequests = <EnginePreviewFramesRequest>[];
  final thumbnailRequests = <EngineVideoThumbnailRequest>[];
  final Completer<void> _thumbnailRelease = Completer<void>();

  void releaseThumbnail() {
    if (!_thumbnailRelease.isCompleted) {
      _thumbnailRelease.complete();
    }
  }

  @override
  Future<EngineOperationResult<EnginePreviewFramesResult>>
  generatePreviewFrames(EnginePreviewFramesRequest request) async {
    previewRequests.add(request);
    return EngineOperationResult(
      sessionId: 'session-1',
      requestId: 'preview-1',
      workId: 'work-preview',
      sequence: 1,
      queueKind: EngineQueueKind.control,
      value: EnginePreviewFramesResult(
        outputDirectory: request.outputDirectory,
        frames: List<EnginePreviewFrameArtifact>.generate(
          request.timestampsUs.length,
          (index) => EnginePreviewFrameArtifact(
            index: index,
            requestedTimestampUs: request.timestampsUs[index],
            decodedTimestampUs: request.timestampsUs[index] + 1000,
            width: 960,
            height: 540,
            outputPath: '${request.outputDirectory}/frame-$index.bmp',
          ),
        ),
      ),
    );
  }

  @override
  Future<EngineOperationResult<EngineVideoThumbnailResult>>
  generateVideoThumbnail(EngineVideoThumbnailRequest request) async {
    thumbnailRequests.add(request);
    if (pauseThumbnail) {
      await _thumbnailRelease.future;
    }
    final file = File(request.outputPath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(const <int>[0x42, 0x4d]);
    return EngineOperationResult(
      sessionId: 'session-1',
      requestId: 'thumbnail-1',
      workId: 'work-thumbnail',
      sequence: 2,
      queueKind: EngineQueueKind.control,
      value: EngineVideoThumbnailResult(
        outputPath: request.outputPath,
        requestedTimestampUs: 1000000,
        decodedTimestampUs: 1001000,
        width: 80,
        height: 45,
      ),
    );
  }
}
