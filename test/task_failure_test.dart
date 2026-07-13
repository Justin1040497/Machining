import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/infrastructure/repositories/mappers/task_failure_json_mapper.dart';

void main() {
  group('MediaTask analysis lifecycle', () {
    test('draft becomes executable only after a persisted analysis result', () {
      final draft = MediaTask.draft(
        inputPath: '/videos/demo.mp4',
        fileName: 'demo.mp4',
        mediaKind: MediaKind.video,
        sortOrder: 0,
      );

      expect(draft.status, TaskStatus.awaitingAnalysis);
      expect(draft.canStartExecution, isFalse);

      final analyzing = draft.markAnalyzing();
      expect(analyzing.status, TaskStatus.analyzing);
      expect(analyzing.markAnalysisReady().status, TaskStatus.analyzing);

      final ready = analyzing
          .withAnalysisResult(MediaAnalysisResult(durationMs: 1000))
          .markAnalysisReady();
      expect(ready.status, TaskStatus.pending);
      expect(ready.isAnalysisReady, isTrue);
      expect(ready.canStartExecution, isTrue);
    });

    test('paused database state is not eligible for a new execution', () {
      final paused = MediaTask.draft(
        inputPath: '/videos/demo.mp4',
        fileName: 'demo.mp4',
        mediaKind: MediaKind.video,
        sortOrder: 0,
      ).copyWith(status: TaskStatus.paused);

      expect(paused.canStartExecution, isFalse);
    });

    test('retry keeps valid analysis for execution failures', () {
      final ready =
          MediaTask.draft(
                inputPath: '/videos/demo.mp4',
                fileName: 'demo.mp4',
                mediaKind: MediaKind.video,
                sortOrder: 0,
              )
              .markAnalyzing()
              .withAnalysisResult(MediaAnalysisResult(durationMs: 1000))
              .markAnalysisReady();
      final failed = ready.markFailed(
        const TaskFailure(
          stage: TaskFailureStage.processing,
          code: TaskFailureCode.processExitedAbnormally,
          userMessage: '媒体处理失败',
          technicalSummary: 'exit code 1',
          occurredAt: 10,
          retryable: true,
        ),
      );

      final retried = failed.markPendingForRetry();
      expect(retried.status, TaskStatus.pending);
      expect(retried.analysisResult, isNotNull);
      expect(retried.failure, isNull);
    });
  });

  group('TaskFailure JSON', () {
    const failure = TaskFailure(
      stage: TaskFailureStage.outputPublication,
      code: TaskFailureCode.outputPublishFailed,
      userMessage: '无法发布最终文件',
      technicalSummary: 'rename returned access denied',
      occurredAt: 123,
      retryable: true,
    );

    test('round trips version 1 payload', () {
      final decoded = decodeTaskFailure(
        encodeTaskFailure(failure),
        status: TaskStatus.failed,
        legacyErrorMessage: null,
        legacyAnalysisErrorMessage: null,
        failedAt: null,
      )!;

      expect(decoded.stage, failure.stage);
      expect(decoded.code, failure.code);
      expect(decoded.userMessage, failure.userMessage);
      expect(decoded.technicalSummary, failure.technicalSummary);
      expect(decoded.occurredAt, failure.occurredAt);
      expect(decoded.retryable, failure.retryable);
    });

    test('restores legacy analysis failure', () {
      final decoded = decodeTaskFailure(
        null,
        status: TaskStatus.failed,
        legacyErrorMessage: 'ffprobe stderr',
        legacyAnalysisErrorMessage: '媒体分析失败',
        failedAt: 99,
      )!;

      expect(decoded.stage, TaskFailureStage.analysis);
      expect(decoded.code, TaskFailureCode.unknown);
      expect(decoded.userMessage, '媒体分析失败');
      expect(decoded.technicalSummary, 'ffprobe stderr');
    });

    test('malformed JSON falls back without blocking task loading', () {
      final decoded = decodeTaskFailure(
        '{broken',
        status: TaskStatus.failed,
        legacyErrorMessage: 'legacy error',
        legacyAnalysisErrorMessage: null,
        failedAt: 88,
      )!;

      expect(decoded.stage, TaskFailureStage.unknown);
      expect(decoded.code, TaskFailureCode.unknown);
      expect(decoded.technicalSummary, 'legacy error');
    });

    test('future enum values degrade to unknown', () {
      final decoded = decodeTaskFailure(
        '{"version":1,"stage":"futureStage","code":"futureCode",'
        '"userMessage":"提示","technicalSummary":"details",'
        '"occurredAt":1,"retryable":true}',
        status: TaskStatus.failed,
        legacyErrorMessage: null,
        legacyAnalysisErrorMessage: null,
        failedAt: null,
      )!;

      expect(decoded.stage, TaskFailureStage.unknown);
      expect(decoded.code, TaskFailureCode.unknown);
      expect(decoded.userMessage, '提示');
    });
  });
}
