import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/infrastructure/services/engine/local_fengine_gateway.dart';

void main() {
  final executablePath = Platform.environment['FRAMELEAN_FENGINE_BINARY'];
  final remuxProgressDelay =
      Platform.environment['FRAMELEAN_TEST_REMUX_PROGRESS_DELAY_MS'];

  test(
    'real daemon closes the batch analysis, artifact, LIFO, and reconnect loop',
    () async {
      final enginePath = executablePath!;
      expect(
        File(enginePath).existsSync(),
        isTrue,
        reason: 'FRAMELEAN_FENGINE_BINARY must identify a built FEngine',
      );

      final root = await Directory.systemTemp.createTemp(
        'framelean-client-engine-e2e-',
      );
      final snapshotDirectory = Directory(
        '${root.path}${Platform.pathSeparator}snapshots',
      );
      final videoFixture = _uncompressedAviFixture(frameCount: 3);
      final audioFixture = _pcmWavFixture(sampleCount: 400_000);
      final taskIds = <String>['task-a1', 'task-a2', 'task-a3'];
      const videoTaskId = 'task-video';
      final analysisTaskIds = <String>[...taskIds, videoTaskId];
      final inputFiles = <String, File>{};
      for (final (index, taskId) in taskIds.indexed) {
        final input = File(
          '${root.path}${Platform.pathSeparator}${taskId}_$index.wav',
        );
        await input.writeAsBytes(audioFixture, flush: true);
        inputFiles[taskId] = input;
      }
      final videoInput = File(
        '${root.path}${Platform.pathSeparator}$videoTaskId.avi',
      );
      await videoInput.writeAsBytes(videoFixture, flush: true);
      inputFiles[videoTaskId] = videoInput;

      final gateways = <LocalFEngineGateway>[];
      StreamSubscription<EngineWorkEvent>? analysisEvents;
      StreamSubscription<EngineWorkEvent>? executionEvents;
      var phase = 'connecting the first daemon client';
      try {
        final firstGateway = _gateway(
          executablePath: enginePath,
          snapshotDirectory: snapshotDirectory.path,
        );
        gateways.add(firstGateway);
        final firstConnection = await firstGateway.connect();
        expect(firstConnection.resumed, isFalse);

        final analyzedTaskIds = <String>{};
        final analysesCompleted = Completer<void>();
        analysisEvents = firstGateway.events.listen((event) {
          final clientTaskId = event.clientTaskId;
          if (event.type == EngineWorkEventType.failed &&
              clientTaskId != null &&
              analysisTaskIds.contains(clientTaskId) &&
              !analysesCompleted.isCompleted) {
            analysesCompleted.completeError(
              StateError(
                'analysis failed for $clientTaskId: '
                '${event.engineCode} ${event.message}',
              ),
            );
          }
          if (event.type == EngineWorkEventType.completed &&
              clientTaskId != null &&
              analysisTaskIds.contains(clientTaskId)) {
            analyzedTaskIds.add(clientTaskId);
            if (analyzedTaskIds.length == analysisTaskIds.length &&
                !analysesCompleted.isCompleted) {
              analysesCompleted.complete();
            }
          }
        });

        phase = 'submitting the analysis batch';
        final analysisBatch = await firstGateway.submitAnalysisBatch([
          for (final (index, taskId) in analysisTaskIds.indexed)
            EngineAnalysisRequest(
              clientTaskId: taskId,
              clientFileId: 'file-${index + 1}',
              source: _sourceFacts(inputFiles[taskId]!),
              taskMode: taskId == videoTaskId
                  ? EngineTaskMode.videoConvert
                  : EngineTaskMode.audioConvert,
              requestId: 'analysis-${index + 1}',
            ),
        ]);
        expect(
          analysisBatch.value.items.map((item) => item.clientTaskId),
          analysisTaskIds,
        );
        expect(
          analysisBatch.value.items.every(
            (item) => item.queueKind == EngineQueueKind.analysis,
          ),
          isTrue,
        );
        phase = 'waiting for the batch analysis terminal events';
        await analysesCompleted.future.timeout(const Duration(seconds: 20));
        await analysisEvents.cancel();
        analysisEvents = null;

        phase = 'loading the authoritative engine snapshot after analysis';
        final postAnalysisSnapshot =
            (await firstGateway.getEngineSnapshot()).value;
        final terminalAnalyses = <String, EngineTerminalAnalysisSnapshot>{
          for (final terminal in postAnalysisSnapshot.terminalAnalyses)
            if (analysisTaskIds.contains(terminal.clientTaskId))
              terminal.clientTaskId: terminal,
        };
        expect(terminalAnalyses.keys.toSet(), analysisTaskIds.toSet());
        expect(
          terminalAnalyses.values.every((terminal) => terminal.succeeded),
          isTrue,
        );

        phase = 'loading analysis snapshots';
        final analysisSnapshots = <String, EngineAnalysisSnapshotDocument>{};
        for (final taskId in analysisTaskIds) {
          final terminal = terminalAnalyses[taskId]!;
          final snapshot = (await firstGateway.getAnalysisSnapshot(
            terminal.analysisId,
          )).value;
          expect(snapshot.analysisId, terminal.analysisId);
          expect(snapshot.analysisRevision, terminal.analysisRevision);
          expect(snapshot.validity.isValid, isTrue);
          if (taskIds.contains(taskId)) {
            expect(snapshot.configurationOptions.candidateIds, isNotEmpty);
          }
          analysisSnapshots[taskId] = snapshot;
        }

        phase = 'generating preview frames through the control queue';
        final previewDirectory = Directory(
          '${root.path}${Platform.pathSeparator}previews',
        );
        final preview = await firstGateway.generatePreviewFrames(
          EnginePreviewFramesRequest(
            clientTaskId: taskIds.first,
            source: _sourceFacts(inputFiles[videoTaskId]!),
            outputDirectory: previewDirectory.path,
            timestampsUs: const <int>[0, 1_000_000],
            maxWidth: 1,
            requestId: 'preview-a1',
          ),
        );
        expect(preview.value.frames, hasLength(2));
        for (final frame in preview.value.frames) {
          expect(frame.width, 1);
          expect(frame.height, 1);
          expect(await _isBmp(File(frame.outputPath)), isTrue);
        }

        phase = 'generating a video thumbnail through the control queue';
        final thumbnailFile = File(
          '${root.path}${Platform.pathSeparator}thumbnail.bmp',
        );
        final thumbnail = await firstGateway.generateVideoThumbnail(
          EngineVideoThumbnailRequest(
            clientTaskId: taskIds.first,
            source: _sourceFacts(inputFiles[videoTaskId]!),
            outputPath: thumbnailFile.path,
            durationUs: 1_500_000,
            maxWidth: 1,
            requestId: 'thumbnail-a1',
          ),
        );
        expect(thumbnail.value.outputPath, thumbnailFile.path);
        expect(thumbnail.value.width, 1);
        expect(thumbnail.value.height, 1);
        expect(await _isBmp(thumbnailFile), isTrue);

        phase = 'submitting the execution queue';
        final terminalOrder = <String>[];
        final executionsCompleted = Completer<void>();
        executionEvents = firstGateway.events.listen((event) {
          final clientTaskId = event.clientTaskId;
          if (clientTaskId == null || !taskIds.contains(clientTaskId)) {
            return;
          }
          if (event.type == EngineWorkEventType.executionFailed ||
              event.type == EngineWorkEventType.executionCancelled) {
            if (!executionsCompleted.isCompleted) {
              executionsCompleted.completeError(
                StateError(
                  'execution failed for $clientTaskId: '
                  '${event.engineCode} ${event.message}',
                ),
              );
            }
            return;
          }
          if (event.type == EngineWorkEventType.executionCompleted) {
            terminalOrder.add(clientTaskId);
            if (terminalOrder.length == taskIds.length &&
                !executionsCompleted.isCompleted) {
              executionsCompleted.complete();
            }
          }
        });

        final outputFiles = <File>[];
        final submissions = <EngineExecutionSubmission>[];
        for (final (index, taskId) in taskIds.indexed) {
          final snapshot = analysisSnapshots[taskId]!;
          final output = File(
            '${root.path}${Platform.pathSeparator}output-${index + 1}.wav',
          );
          outputFiles.add(output);
          final selection = engineConfigurationSelectionToJson(
            EngineManualConfigurationSelection(
              candidateId: snapshot.configurationOptions.candidateIds.first,
            ),
          );
          final submission = await firstGateway.submitExecution(
            EngineExecutionRequest(
              clientTaskId: taskId,
              analysisId: snapshot.analysisId,
              expectedRevision: snapshot.analysisRevision,
              selection: selection,
              requestedOutputPath: output.path,
              collisionPolicy: EngineOutputCollisionPolicy.failIfExists,
              requestId: 'execution-${index + 1}',
            ),
          );
          submissions.add(submission.value);
        }

        phase = 'preempting one auxiliary slot with A3';
        await firstGateway.preemptAndStart(submissions[2].executionId);
        phase = 'loading the per-pool LIFO snapshot';
        final nestedSnapshot = (await firstGateway.getEngineSnapshot()).value;
        expect(
          nestedSnapshot.executionLane.activeExecutions
              .map((entry) => entry.executionId)
              .toSet(),
          <String>{submissions[0].executionId, submissions[2].executionId},
        );
        expect(nestedSnapshot.executionLane.normalWaiting, isEmpty);
        expect(
          nestedSnapshot.executionLane.auxiliaryResumeStack
              .map((entry) => entry.executionId)
              .toList(),
          <String>[submissions[1].executionId],
        );

        phase = 'waiting for the real execution terminal events';
        await executionsCompleted.future.timeout(const Duration(seconds: 30));
        expect(terminalOrder.toSet(), taskIds.toSet());
        await executionEvents.cancel();
        executionEvents = null;
        for (final output in outputFiles) {
          expect(await output.exists(), isTrue);
          expect(await output.length(), greaterThan(44));
        }

        phase = 'reconnecting to the same daemon session';
        final sessionId = firstConnection.sessionId;
        await firstGateway.close();

        final reconnectedGateway = _gateway(
          executablePath: enginePath,
          snapshotDirectory: snapshotDirectory.path,
        );
        gateways.add(reconnectedGateway);
        final reconnected = await reconnectedGateway.connect();
        expect(reconnected.resumed, isTrue);
        expect(reconnected.sessionId, sessionId);

        final reconciledSnapshot =
            (await reconnectedGateway.getEngineSnapshot()).value;
        expect(reconciledSnapshot.executionLane.activeExecutions, isEmpty);
        expect(reconciledSnapshot.executionLane.normalWaiting, isEmpty);
        expect(reconciledSnapshot.executionLane.videoResumeStack, isEmpty);
        expect(reconciledSnapshot.executionLane.auxiliaryResumeStack, isEmpty);
        final completedTasks = reconciledSnapshot.terminalExecutions
            .where(
              (terminal) =>
                  taskIds.contains(terminal.clientTaskId) &&
                  terminal.state == EngineExecutionState.completed,
            )
            .map((terminal) => terminal.clientTaskId)
            .toSet();
        expect(completedTasks, taskIds.toSet());

        phase = 'reanalyzing a completed output';
        final outputAnalysis = await reconnectedGateway.analyze(
          EngineAnalysisRequest(
            clientTaskId: 'task-output',
            clientFileId: 'file-output',
            source: _sourceFacts(outputFiles.first),
            taskMode: EngineTaskMode.audioConvert,
            requestId: 'analysis-output',
          ),
        );
        expect(
          outputAnalysis.value.analysis.mediaAnalysisStatus,
          EngineMediaAnalysisStatus.complete,
        );
        expect(outputAnalysis.value.snapshot?.validity.isValid, isTrue);

        await reconnectedGateway.shutdownEngine();
      } on Object catch (error, stackTrace) {
        Error.throwWithStackTrace(
          StateError('real FEngine E2E failed while $phase: $error'),
          stackTrace,
        );
      } finally {
        await analysisEvents?.cancel();
        await executionEvents?.cancel();
        for (final gateway in gateways.reversed) {
          try {
            await gateway.shutdownEngine();
          } on Object {
            // Best effort: another gateway may already have stopped the daemon.
          }
        }
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      }
    },
    skip: executablePath == null || remuxProgressDelay == null
        ? 'set FRAMELEAN_FENGINE_BINARY and '
              'FRAMELEAN_TEST_REMUX_PROGRESS_DELAY_MS to run the real '
              'FEngine E2E'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

LocalFEngineGateway _gateway({
  required String executablePath,
  required String snapshotDirectory,
}) {
  return LocalFEngineGateway(
    executablePath: executablePath,
    snapshotDirectory: snapshotDirectory,
    clientName: 'FrameLean Gateway E2E',
    clientVersion: 'test',
  );
}

EngineSourceFacts _sourceFacts(File file) {
  return EngineSourceFacts(
    path: file.absolute.path,
    fileSizeBytes: file.lengthSync(),
    modifiedTimeUnixNanos: null,
  );
}

Future<bool> _isBmp(File file) async {
  if (!await file.exists()) {
    return false;
  }
  final bytes = await file
      .openRead(0, 2)
      .fold<List<int>>(<int>[], (prefix, chunk) => <int>[...prefix, ...chunk]);
  return bytes.length == 2 && bytes[0] == 0x42 && bytes[1] == 0x4d;
}

Uint8List _pcmWavFixture({required int sampleCount}) {
  const sampleRate = 8000;
  const channels = 1;
  const bitsPerSample = 16;
  final dataSize = sampleCount * channels * (bitsPerSample ~/ 8);
  final bytes = BytesBuilder(copy: false)
    ..add(ascii.encode('RIFF'))
    ..add(_u32(36 + dataSize))
    ..add(ascii.encode('WAVEfmt '))
    ..add(_u32(16))
    ..add(_u16(1))
    ..add(_u16(channels))
    ..add(_u32(sampleRate))
    ..add(_u32(sampleRate * channels * (bitsPerSample ~/ 8)))
    ..add(_u16(channels * (bitsPerSample ~/ 8)))
    ..add(_u16(bitsPerSample))
    ..add(ascii.encode('data'))
    ..add(_u32(dataSize));
  final samples = Uint8List(dataSize);
  final pattern = ByteData(32);
  for (var index = 0; index < 16; index++) {
    pattern.setInt16(index * 2, index < 8 ? 4000 : -4000, Endian.little);
  }
  final patternBytes = pattern.buffer.asUint8List();
  for (var offset = 0; offset < samples.length; offset += patternBytes.length) {
    samples.setRange(offset, offset + patternBytes.length, patternBytes);
  }
  bytes.add(samples);
  return bytes.takeBytes();
}

Uint8List _uncompressedAviFixture({required int frameCount}) {
  const width = 2;
  const height = 2;
  const frameBytes = 16;
  final mainHeader = BytesBuilder(copy: false)
    ..add(_u32(500000))
    ..add(_u32(frameBytes * 2))
    ..add(_u32(0))
    ..add(_u32(0x10))
    ..add(_u32(frameCount))
    ..add(_u32(0))
    ..add(_u32(1))
    ..add(_u32(frameBytes))
    ..add(_u32(width))
    ..add(_u32(height))
    ..add(Uint8List(16));

  final streamHeader = BytesBuilder(copy: false)
    ..add(ascii.encode('vids'))
    ..add(ascii.encode('DIB '))
    ..add(_u32(0))
    ..add(_u16(0))
    ..add(_u16(0))
    ..add(_u32(0))
    ..add(_u32(1))
    ..add(_u32(2))
    ..add(_u32(0))
    ..add(_u32(frameCount))
    ..add(_u32(frameBytes))
    ..add(_u32(0xffffffff))
    ..add(_u32(0))
    ..add(_i16(0))
    ..add(_i16(0))
    ..add(_i16(width))
    ..add(_i16(height));

  final bitmapInfo = BytesBuilder(copy: false)
    ..add(_u32(40))
    ..add(_i32(width))
    ..add(_i32(height))
    ..add(_u16(1))
    ..add(_u16(24))
    ..add(_u32(0))
    ..add(_u32(frameBytes))
    ..add(_i32(0))
    ..add(_i32(0))
    ..add(_u32(0))
    ..add(_u32(0));

  final streamList = _listChunk(
    'strl',
    _concat([
      _riffChunk('strh', streamHeader.takeBytes()),
      _riffChunk('strf', bitmapInfo.takeBytes()),
    ]),
  );
  final headerList = _listChunk(
    'hdrl',
    _concat([_riffChunk('avih', mainHeader.takeBytes()), streamList]),
  );

  final movieData = BytesBuilder(copy: false);
  final indexData = BytesBuilder(copy: false);
  final blackFrame = Uint8List(frameBytes);
  final visibleFrame = _visibleBgrFrame();
  var offset = 4;
  for (var index = 0; index < frameCount; index++) {
    final frame = index < 2 ? blackFrame : visibleFrame;
    movieData.add(_riffChunk('00db', frame));
    indexData
      ..add(ascii.encode('00db'))
      ..add(_u32(0x10))
      ..add(_u32(offset))
      ..add(_u32(frame.length));
    offset += 8 + frame.length + (frame.length & 1);
  }

  return _riffFile(
    'AVI ',
    _concat([
      headerList,
      _listChunk('movi', movieData.takeBytes()),
      _riffChunk('idx1', indexData.takeBytes()),
    ]),
  );
}

Uint8List _visibleBgrFrame() {
  return Uint8List.fromList(<int>[
    0,
    255,
    0,
    0,
    255,
    0,
    0,
    0,
    0,
    255,
    0,
    0,
    255,
    0,
    0,
    0,
  ]);
}

Uint8List _riffFile(String kind, Uint8List contents) {
  return _concat([
    ascii.encode('RIFF'),
    _u32(4 + contents.length),
    ascii.encode(kind),
    contents,
  ]);
}

Uint8List _listChunk(String kind, Uint8List contents) {
  return _riffChunk('LIST', _concat([ascii.encode(kind), contents]));
}

Uint8List _riffChunk(String tag, Uint8List data) {
  return _concat([
    ascii.encode(tag),
    _u32(data.length),
    data,
    if (data.length.isOdd) Uint8List(1),
  ]);
}

Uint8List _concat(Iterable<List<int>> chunks) {
  final builder = BytesBuilder(copy: false);
  for (final chunk in chunks) {
    builder.add(chunk);
  }
  return builder.takeBytes();
}

Uint8List _u16(int value) {
  return (ByteData(2)..setUint16(0, value, Endian.little)).buffer.asUint8List();
}

Uint8List _i16(int value) {
  return (ByteData(2)..setInt16(0, value, Endian.little)).buffer.asUint8List();
}

Uint8List _u32(int value) {
  return (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List();
}

Uint8List _i32(int value) {
  return (ByteData(4)..setInt32(0, value, Endian.little)).buffer.asUint8List();
}
