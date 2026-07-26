import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/services/analysis/media_analysis_queue.dart';
import 'package:framelean/domain/library.dart';

void main() {
  group('MediaAnalysisQueue', () {
    test('tracks every concurrently analyzing task', () async {
      final completions = <String, Completer<void>>{
        'first': Completer<void>(),
        'second': Completer<void>(),
      };
      final queue = MediaAnalysisQueue(
        analyzeTask: (taskId) async {
          await completions[taskId]!.future;
          return null;
        },
      );
      addTearDown(queue.stop);

      queue.enqueueAll(completions.keys);
      await Future<void>.delayed(Duration.zero);

      expect(queue.isAnalyzing('first'), isTrue);
      expect(queue.isAnalyzing('second'), isTrue);
      expect(queue.snapshot.analyzing, 2);

      for (final completer in completions.values) {
        completer.complete();
      }
      await queue.waitForCompletion();

      expect(queue.isAnalyzing('first'), isFalse);
      expect(queue.isAnalyzing('second'), isFalse);
    });

    test('records a failed task as failed instead of succeeded', () async {
      final failedTask =
          MediaTask.draft(
            inputPath: '/videos/failed.mp4',
            fileName: 'failed.mp4',
            mediaKind: MediaKind.video,
            sortOrder: 0,
          ).markFailed(
            const TaskFailure(
              stage: TaskFailureStage.analysis,
              code: TaskFailureCode.analysisFailed,
              userMessage: 'analysis failed',
              technicalSummary: 'FLL returned a failed AnalysisResult',
              occurredAt: 1,
              retryable: true,
            ),
          );
      final queue = MediaAnalysisQueue(analyzeTask: (_) async => failedTask);
      addTearDown(queue.stop);

      queue.enqueue('failed');
      await queue.waitForCompletion();

      expect(queue.snapshot.failed, 1);
      expect(queue.snapshot.succeeded, 0);
    });

    test('stop waits for active analysis cleanup before closing', () async {
      final completion = Completer<void>();
      final started = Completer<void>();
      final queue = MediaAnalysisQueue(
        analyzeTask: (taskId) async {
          started.complete();
          await completion.future;
          return null;
        },
      );

      queue.enqueue('active');
      await started.future;

      var stopped = false;
      final stopFuture = queue.stop().then((_) => stopped = true);
      await Future<void>.delayed(Duration.zero);

      expect(stopped, isFalse);
      completion.complete();
      await stopFuture;
      expect(stopped, isTrue);
    });
  });
}
