import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/application/models/engine_analysis_documents.dart';
import 'package:framelean/application/models/engine_analysis_projection.dart';
import 'package:framelean/application/repositories/app_settings_repository.dart';
import 'package:framelean/application/repositories/engine_analysis_projection_repository.dart';
import 'package:framelean/application/repositories/imported_media_batch_persistence.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/application/repositories/task_folder_repository.dart';
import 'package:framelean/application/repositories/workbench_order_revision_store.dart';
import 'package:framelean/application/services/analysis/media_analysis_queue.dart';
import 'package:framelean/application/services/engine/engine_gateway.dart';
import 'package:framelean/application/services/input_runtime/source_file_checker.dart';
import 'package:framelean/application/services/input_runtime/source_file_fingerprint_reader.dart';
import 'package:framelean/application/use_cases/app_settings/apply_output_settings_to_existing_tasks_use_case.dart';
import 'package:framelean/app/providers/engine_provider.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/entities/task_folder.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/output_location_mode.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/engine_configuration_reference.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/domain/value_objects/media_analysis_result.dart';
import 'package:framelean/domain/value_objects/source_file_fingerprint.dart';
import 'package:framelean/domain/value_objects/video_task_config.dart';
import 'package:framelean/features/workbench/providers/media_task_notifier.dart';
import 'package:framelean/app/providers/execution_provider.dart';
import 'package:framelean/app/providers/input_runtime_provider.dart';
import 'package:framelean/app/providers/repository_provider.dart';

void main() {
  group('MediaTaskListNotifier', () {
    test('keeps already missing source tasks while loading history', () async {
      final missingTask = videoTask(
        status: TaskStatus.missingSource,
      ).copyWith(sourceFileFingerprint: testFingerprint);
      final repository = FakeMediaTaskRepository([missingTask]);
      final fingerprintReader = FakeSourceFileFingerprintReader();
      final container = testContainer(
        repository: repository,
        sourceFileChecker: const FakeSourceFileChecker(existingPaths: {}),
        fingerprintReader: fingerprintReader,
      );

      final tasks = await container.read(mediaTaskListProvider.future);

      expect(tasks, hasLength(1));
      expect(tasks.single.id, missingTask.id);
      expect(tasks.single.status, TaskStatus.missingSource);
      expect(tasks.single.config, missingTask.config);
      expect(repository.replaceAllCallCount, 0);
      expect(fingerprintReader.readPaths, isEmpty);
    });

    test('marks missing source tasks without dropping the task', () async {
      final pendingTask = videoTask(
        status: TaskStatus.pending,
      ).copyWith(sourceFileFingerprint: testFingerprint);
      final repository = FakeMediaTaskRepository([pendingTask]);
      final fingerprintReader = FakeSourceFileFingerprintReader();
      final container = testContainer(
        repository: repository,
        sourceFileChecker: const FakeSourceFileChecker(existingPaths: {}),
        fingerprintReader: fingerprintReader,
      );

      final tasks = await container.read(mediaTaskListProvider.future);

      expect(tasks, hasLength(1));
      expect(tasks.single.id, pendingTask.id);
      expect(tasks.single.status, TaskStatus.missingSource);
      expect(repository.replaceAllCallCount, 1);
      expect(repository.tasks.single.status, TaskStatus.missingSource);
      expect(fingerprintReader.readPaths, isEmpty);
    });

    test('creates new drafts from app settings defaults', () async {
      final repository = FakeMediaTaskRepository([]);
      final container = testContainer(
        repository: repository,
        sourceFileChecker: const FakeSourceFileChecker(
          existingPaths: {'/videos/source.mp4'},
        ),
        fingerprintReader: FakeSourceFileFingerprintReader(
          fingerprint: testFingerprint,
        ),
        appSettingsRepository: FakeAppSettingsRepository(
          AppSettings.initial().copyWith(
            defaultOutputDirectory: '/Users/leftzhou/Desktop',
            saveOutputToSourceDirectory: true,
            defaultOutputVideoCodec: VideoCodec.hevc,
            defaultSmartPreset: SmartCompressionPreset.chat,
          ),
        ),
      );

      await container.read(mediaTaskListProvider.future);
      final task = await container
          .read(mediaTaskListProvider.notifier)
          .createDraftFromPath('/videos/source.mp4');

      expect(task.config.outputDirectory, isEmpty);
      expect(task.config.videoCodec, VideoCodec.hevc);
      expect(task.config.smartPreset, SmartCompressionPreset.chat);
      expect(task.config.outputFileName, 'source-压缩');
    });

    test(
      'batch imports persist awaiting-analysis tasks before analysis takes over',
      () async {
        final repository = FakeMediaTaskRepository([]);
        final container = testContainer(
          repository: repository,
          sourceFileChecker: const FakeSourceFileChecker(
            existingPaths: {'/videos/first.mp4', '/videos/second.mov'},
          ),
          fingerprintReader: FakeSourceFileFingerprintReader(
            fingerprint: testFingerprint,
          ),
        );

        await container.read(mediaTaskListProvider.future);
        final tasks = await container
            .read(mediaTaskListProvider.notifier)
            .createDraftsFromPaths([
              '/videos/first.mp4',
              '/videos/unsupported.txt',
              '/videos/second.mov',
            ]);

        expect(tasks, hasLength(2));
        expect(
          tasks.every((task) => task.status == TaskStatus.awaitingAnalysis),
          isTrue,
        );
      },
    );

    test('refreshes UI state after a fast analysis finishes', () async {
      final repository = FakeMediaTaskRepository([]);
      final queue = MediaAnalysisQueue(
        analyzeTask: (taskId) async {
          final task = (await repository.loadTaskById(taskId))!;
          final analyzedTask = task
              .markAnalyzing()
              .withAnalysisResult(MediaAnalysisResult(durationMs: 1000))
              .markAnalysisReady();
          await repository.saveTask(analyzedTask);
          return analyzedTask;
        },
      );
      addTearDown(queue.stop);
      final container = testContainer(
        repository: repository,
        sourceFileChecker: const FakeSourceFileChecker(
          existingPaths: {'/videos/fast.mp4'},
        ),
        fingerprintReader: FakeSourceFileFingerprintReader(
          fingerprint: testFingerprint,
        ),
        analysisQueue: queue,
      );
      addTearDown(container.dispose);

      await container.read(mediaTaskListProvider.future);
      await container
          .read(mediaTaskListProvider.notifier)
          .createDraftsFromPaths(['/videos/fast.mp4']);
      await queue.waitForCompletion();
      await Future<void>.delayed(Duration.zero);

      final task = container.read(mediaTaskListProvider).requireValue.single;
      expect(task.status, TaskStatus.pending);
      expect(task.analysisResult, isNotNull);
    });

    test(
      'increments output template version for repeated source imports',
      () async {
        final existingTask = readyVideoTask(id: 'source', sortOrder: 0);
        final repository = FakeMediaTaskRepository([existingTask]);
        final container = testContainer(
          repository: repository,
          sourceFileChecker: FakeSourceFileChecker(
            existingPaths: {existingTask.inputPath},
          ),
          fingerprintReader: FakeSourceFileFingerprintReader(
            fingerprint: testFingerprint,
          ),
          appSettingsRepository: FakeAppSettingsRepository(
            AppSettings.initial().copyWith(
              defaultOutputFileNameTemplate: '{source}-{version}',
            ),
          ),
        );

        await container.read(mediaTaskListProvider.future);
        final task = await container
            .read(mediaTaskListProvider.notifier)
            .createDraftFromPath(existingTask.inputPath);

        expect(task.config.outputFileName, 'source-v2');
      },
    );

    test(
      'applies output settings to retryable tasks without resetting media config',
      () async {
        final renamedTask = readyVideoTask(id: 'source', sortOrder: 0).copyWith(
          fileName: '1.mp4',
          config: systemOutputVideoConfig(
            outputDirectory: '/old',
            outputFileName: 'old',
            videoCodec: VideoCodec.h264,
          ),
        );
        final failedTask = readyVideoTask(id: 'failed', sortOrder: 1).copyWith(
          status: TaskStatus.failed,
          config: systemOutputVideoConfig(
            outputDirectory: '/old',
            outputFileName: 'old',
            videoCodec: VideoCodec.h264,
          ),
        );
        final cancelledTask = readyVideoTask(id: 'cancelled', sortOrder: 2)
            .copyWith(
              status: TaskStatus.cancelled,
              config: systemOutputVideoConfig(
                outputDirectory: '/old',
                outputFileName: 'old',
                videoCodec: VideoCodec.h264,
              ),
            );
        final runningTask = readyVideoTask(id: 'running', sortOrder: 3)
            .copyWith(
              status: TaskStatus.running,
              config: systemOutputVideoConfig(
                outputDirectory: '/old',
                outputFileName: 'old',
                videoCodec: VideoCodec.h264,
              ),
            );
        final repository = FakeMediaTaskRepository([
          renamedTask,
          failedTask,
          cancelledTask,
          runningTask,
        ]);
        await ApplyOutputSettingsToExistingTasksUseCase(
          repository: repository,
        ).call(
          AppSettings.initial().copyWith(
            defaultOutputDirectory: '/exports',
            saveOutputToSourceDirectory: false,
            defaultOutputFileNameTemplate: '{source}-{codec}',
            defaultOutputVideoCodec: VideoCodec.hevc,
          ),
        );

        final updatedTask = repository.taskById(renamedTask.id);
        expect(
          updatedTask.config.outputLocationMode,
          OutputLocationMode.system,
        );
        expect(updatedTask.config.outputDirectory, isEmpty);
        expect(updatedTask.config.outputFileName, 'source-h264');
        expect(updatedTask.config.videoCodec, VideoCodec.h264);
        expect(updatedTask.config.outputFileName, isNot(contains('1-')));
        expect(
          repository.taskById(failedTask.id).config.outputDirectory,
          isEmpty,
        );
        expect(
          repository.taskById(cancelledTask.id).config.outputDirectory,
          isEmpty,
        );
        expect(
          repository.taskById(runningTask.id).config.outputDirectory,
          '/old',
        );
      },
    );

    test('retry applies the latest output settings', () async {
      final failedTask = readyVideoTask(id: 'source', sortOrder: 0).copyWith(
        fileName: '1.mp4',
        status: TaskStatus.failed,
        config: systemOutputVideoConfig(
          outputDirectory: '/old',
          outputFileName: 'old',
          videoCodec: VideoCodec.h264,
        ),
      );
      final repository = FakeMediaTaskRepository([failedTask]);
      final container = testContainer(
        repository: repository,
        sourceFileChecker: FakeSourceFileChecker(
          existingPaths: {failedTask.inputPath},
        ),
        fingerprintReader: FakeSourceFileFingerprintReader(
          fingerprint: testFingerprint,
        ),
        appSettingsRepository: FakeAppSettingsRepository(
          AppSettings.initial().copyWith(
            defaultOutputDirectory: '/retry-output',
            saveOutputToSourceDirectory: false,
            defaultOutputFileNameTemplate: '{source}-{codec}',
            defaultOutputVideoCodec: VideoCodec.hevc,
          ),
        ),
      );

      await container.read(mediaTaskListProvider.future);
      await container
          .read(mediaTaskListProvider.notifier)
          .retryTaskById(failedTask.id);

      final updatedTask = repository.taskById(failedTask.id);
      expect(updatedTask.status, TaskStatus.pending);
      expect(updatedTask.config.outputLocationMode, OutputLocationMode.system);
      expect(updatedTask.config.outputDirectory, isEmpty);
      expect(updatedTask.config.outputFileName, 'source-h264');
      expect(updatedTask.config.videoCodec, VideoCodec.h264);
      expect(updatedTask.config.outputFileName, isNot(contains('1-')));
    });

    test(
      'resolving engine configuration replaces only the target list item',
      () async {
        final previousReference = engineConfigurationReference(
          candidateId: 'candidate-old',
        );
        final sibling = readyVideoTask(id: 'sibling', sortOrder: 0);
        final target = readyVideoTask(id: 'target', sortOrder: 1).copyWith(
          config: MediaTaskConfig.initialVideo().copyWith(
            outputFileName: 'target-output',
            engineConfiguration: previousReference,
          ),
        );
        final repository = FakeMediaTaskRepository([sibling, target]);
        final projectionRepository = FakeEngineAnalysisProjectionRepository(
          engineAnalysisProjection(taskId: target.id),
        );
        final gateway = FakeEngineGateway();
        final container = testContainer(
          repository: repository,
          sourceFileChecker: FakeSourceFileChecker(
            existingPaths: {sibling.inputPath, target.inputPath},
          ),
          fingerprintReader: FakeSourceFileFingerprintReader(
            fingerprint: testFingerprint,
          ),
          analysisProjectionRepository: projectionRepository,
          engineGateway: gateway,
        );
        addTearDown(container.dispose);
        const selection = EngineManualConfigurationSelection(
          candidateId: 'candidate-new',
        );

        await container.read(mediaTaskListProvider.future);
        final resolved = await container
            .read(mediaTaskListProvider.notifier)
            .saveEngineTaskConfiguration(
              taskId: target.id,
              analysisId: 'analysis-1',
              analysisRevision: 4,
              selection: selection,
            );

        final tasks = container.read(mediaTaskListProvider).requireValue;
        expect(tasks.map((task) => task.id), ['sibling', 'target']);
        expect(tasks.first, same(sibling));
        expect(tasks.last, same(resolved));
        expect(repository.taskById(target.id), same(resolved));
        expect(
          resolved.config.engineConfiguration?.candidateId,
          'candidate-new',
        );
      },
    );

    test(
      'saving a selection does not call the legacy Engine resolve RPC',
      () async {
        final previousReference = engineConfigurationReference(
          candidateId: 'candidate-old',
        );
        final sibling = readyVideoTask(id: 'sibling', sortOrder: 0);
        final target = readyVideoTask(id: 'target', sortOrder: 1).copyWith(
          config: MediaTaskConfig.initialVideo().copyWith(
            engineConfiguration: previousReference,
          ),
        );
        final repository = FakeMediaTaskRepository([sibling, target]);
        final gateway = FakeEngineGateway();
        final container = testContainer(
          repository: repository,
          sourceFileChecker: FakeSourceFileChecker(
            existingPaths: {sibling.inputPath, target.inputPath},
          ),
          fingerprintReader: FakeSourceFileFingerprintReader(
            fingerprint: testFingerprint,
          ),
          analysisProjectionRepository: FakeEngineAnalysisProjectionRepository(
            engineAnalysisProjection(taskId: target.id),
          ),
          engineGateway: gateway,
        );
        addTearDown(container.dispose);

        await container.read(mediaTaskListProvider.future);
        final saved = await container
            .read(mediaTaskListProvider.notifier)
            .saveEngineTaskConfiguration(
              taskId: target.id,
              analysisId: 'analysis-1',
              analysisRevision: 4,
              selection: const EngineManualConfigurationSelection(
                candidateId: 'candidate-new',
              ),
            );

        final tasksAfterSave = container
            .read(mediaTaskListProvider)
            .requireValue;
        expect(tasksAfterSave.map((task) => task.id), ['sibling', 'target']);
        expect(saved.config.engineConfiguration?.candidateId, 'candidate-new');
        expect(
          repository
              .taskById(target.id)
              .config
              .engineConfiguration
              ?.candidateId,
          'candidate-new',
        );
      },
    );

    test(
      'new analysis revision wins without overwriting the previous reference',
      () async {
        final previousReference = engineConfigurationReference(
          analysisId: 'analysis-old',
          analysisRevision: 2,
          candidateId: 'candidate-old',
        );
        final sibling = readyVideoTask(id: 'sibling', sortOrder: 0);
        final target = readyVideoTask(id: 'target', sortOrder: 1).copyWith(
          config: MediaTaskConfig.initialVideo().copyWith(
            outputFileName: 'original-output',
            engineConfiguration: previousReference,
          ),
        );
        final repository = FakeMediaTaskRepository([sibling, target]);
        final projectionRepository = FakeEngineAnalysisProjectionRepository(
          engineAnalysisProjection(taskId: target.id),
        );
        late final MediaTask latestTarget;
        latestTarget = target.copyWith(
          config: target.config.copyWith(
            outputFileName: 'latest-output',
            engineConfiguration: previousReference,
          ),
        );
        repository.onSecondTaskLoad = (_) {
          repository.replaceTaskForTest(latestTarget);
        };
        projectionRepository.onSecondLoad = () {
          projectionRepository.projection = engineAnalysisProjection(
            taskId: target.id,
            analysisId: 'analysis-new',
            revision: 1,
            sequence: 20,
          );
        };
        final container = testContainer(
          repository: repository,
          sourceFileChecker: FakeSourceFileChecker(
            existingPaths: {sibling.inputPath, target.inputPath},
          ),
          fingerprintReader: FakeSourceFileFingerprintReader(
            fingerprint: testFingerprint,
          ),
          analysisProjectionRepository: projectionRepository,
        );
        addTearDown(container.dispose);

        await container.read(mediaTaskListProvider.future);
        await expectLater(
          container
              .read(mediaTaskListProvider.notifier)
              .saveEngineTaskConfiguration(
                taskId: target.id,
                analysisId: 'analysis-1',
                analysisRevision: 4,
                selection: const EngineManualConfigurationSelection(
                  candidateId: 'candidate-new',
                ),
              ),
          throwsStateError,
        );

        final tasks = container.read(mediaTaskListProvider).requireValue;
        expect(tasks.map((task) => task.id), ['sibling', 'target']);
        expect(tasks.first, same(sibling));
        expect(tasks.last, same(latestTarget));
        expect(tasks.last.config.outputFileName, 'latest-output');
        expect(tasks.last.config.engineConfiguration, same(previousReference));
        expect(repository.taskById(target.id), same(latestTarget));
      },
    );

    test(
      'source replacement wins without applying the stale engine selection',
      () async {
        final previousReference = engineConfigurationReference(
          candidateId: 'candidate-old',
        );
        final sibling = readyVideoTask(id: 'sibling', sortOrder: 0);
        final target = readyVideoTask(id: 'target', sortOrder: 1).copyWith(
          config: MediaTaskConfig.initialVideo().copyWith(
            engineConfiguration: previousReference,
          ),
        );
        final repository = FakeMediaTaskRepository([sibling, target]);
        final projectionRepository = FakeEngineAnalysisProjectionRepository(
          engineAnalysisProjection(taskId: target.id),
        );
        late final MediaTask replacement;
        replacement = target
            .replaceInputFile(
              newInputPath: '/videos/replacement.mp4',
              newFileName: 'replacement.mp4',
              newMediaKind: MediaKind.video,
            )
            .withSourceFileFingerprint(
              const SourceFileFingerprint(
                fileSize: 512 * 1024 * 1024,
                lastModifiedAt: 2,
              ),
            );
        repository.onSecondTaskLoad = (_) {
          repository.replaceTaskForTest(replacement);
        };
        projectionRepository.onSecondLoad = () {
          projectionRepository.projection = null;
        };
        final container = testContainer(
          repository: repository,
          sourceFileChecker: FakeSourceFileChecker(
            existingPaths: {sibling.inputPath, target.inputPath},
          ),
          fingerprintReader: FakeSourceFileFingerprintReader(
            fingerprint: testFingerprint,
          ),
          analysisProjectionRepository: projectionRepository,
        );
        addTearDown(container.dispose);

        await container.read(mediaTaskListProvider.future);
        await expectLater(
          container
              .read(mediaTaskListProvider.notifier)
              .saveEngineTaskConfiguration(
                taskId: target.id,
                analysisId: 'analysis-1',
                analysisRevision: 4,
                selection: const EngineManualConfigurationSelection(
                  candidateId: 'candidate-new',
                ),
              ),
          throwsStateError,
        );

        final tasks = container.read(mediaTaskListProvider).requireValue;
        expect(tasks.map((task) => task.id), ['sibling', 'target']);
        expect(tasks.first, same(sibling));
        expect(tasks.last, same(replacement));
        expect(tasks.last.inputPath, '/videos/replacement.mp4');
        expect(tasks.last.config.engineConfiguration, isNull);
        expect(repository.taskById(target.id), same(replacement));
      },
    );

    test(
      'reorders tasks by updating sort orders without replacing all tasks',
      () async {
        final firstTask = readyVideoTask(id: 'first', sortOrder: 0);
        final secondTask = readyVideoTask(id: 'second', sortOrder: 1);
        final thirdTask = readyVideoTask(id: 'third', sortOrder: 2);
        final repository = FakeMediaTaskRepository([
          firstTask,
          secondTask,
          thirdTask,
        ]);
        final container = testContainer(
          repository: repository,
          sourceFileChecker: FakeSourceFileChecker(
            existingPaths: {
              firstTask.inputPath,
              secondTask.inputPath,
              thirdTask.inputPath,
            },
          ),
          fingerprintReader: FakeSourceFileFingerprintReader(
            fingerprint: testFingerprint,
          ),
        );

        await container.read(mediaTaskListProvider.future);
        await container
            .read(mediaTaskListProvider.notifier)
            .reorderTasks(oldIndex: 0, newIndex: 3);

        final tasks = container.read(mediaTaskListProvider).requireValue;
        expect(tasks.map((task) => task.id), ['second', 'third', 'first']);
        expect(repository.updateSortOrdersCallCount, 1);
        expect(repository.replaceAllCallCount, 0);
        expect(repository.taskById('first').sortOrder, 2);
        expect(repository.taskById('second').sortOrder, 0);
        expect(repository.taskById('third').sortOrder, 1);
      },
    );

    test('reloads repository order when reorder persistence fails', () async {
      final firstTask = readyVideoTask(id: 'first', sortOrder: 0);
      final secondTask = readyVideoTask(id: 'second', sortOrder: 1);
      final repository = FakeMediaTaskRepository([firstTask, secondTask])
        ..updateSortOrdersError = StateError('sort failed');
      final container = testContainer(
        repository: repository,
        sourceFileChecker: FakeSourceFileChecker(
          existingPaths: {firstTask.inputPath, secondTask.inputPath},
        ),
        fingerprintReader: FakeSourceFileFingerprintReader(
          fingerprint: testFingerprint,
        ),
      );

      await container.read(mediaTaskListProvider.future);

      await expectLater(
        container
            .read(mediaTaskListProvider.notifier)
            .reorderTasks(oldIndex: 0, newIndex: 2),
        throwsStateError,
      );

      final tasks = container.read(mediaTaskListProvider).requireValue;
      expect(tasks.map((task) => task.id), ['first', 'second']);
      expect(repository.updateSortOrdersCallCount, 1);
    });
  });
}

ProviderContainer testContainer({
  required FakeMediaTaskRepository repository,
  required FakeSourceFileChecker sourceFileChecker,
  required FakeSourceFileFingerprintReader fingerprintReader,
  FakeAppSettingsRepository? appSettingsRepository,
  MediaAnalysisQueue? analysisQueue,
  FakeEngineAnalysisProjectionRepository? analysisProjectionRepository,
  FakeEngineGateway? engineGateway,
}) {
  final projectionRepository =
      analysisProjectionRepository ??
      FakeEngineAnalysisProjectionRepository(null);
  final gateway = engineGateway ?? FakeEngineGateway();
  final folderRepository = FakeTaskFolderRepository();
  final queue =
      analysisQueue ?? MediaAnalysisQueue(analyzeTask: repository.loadTaskById);
  return ProviderContainer.test(
    overrides: [
      appSettingsRepositoryProvider.overrideWithValue(
        appSettingsRepository ??
            FakeAppSettingsRepository(AppSettings.initial()),
      ),
      mediaTaskRepositoryProvider.overrideWithValue(repository),
      taskFolderRepositoryProvider.overrideWithValue(folderRepository),
      importedMediaBatchPersistenceProvider.overrideWithValue(
        FakeImportedMediaBatchPersistence(repository, folderRepository),
      ),
      workbenchOrderRevisionStoreProvider.overrideWithValue(
        FakeWorkbenchOrderRevisionStore(),
      ),
      sourceFileCheckerProvider.overrideWithValue(sourceFileChecker),
      sourceFileFingerprintReaderProvider.overrideWithValue(fingerprintReader),
      mediaAnalysisQueueProvider.overrideWith((ref) {
        ref.onDispose(() => queue.stop());
        return queue;
      }),
      engineAnalysisProjectionRepositoryProvider.overrideWithValue(
        projectionRepository,
      ),
      engineGatewayProvider.overrideWith((ref) async => gateway),
    ],
  );
}

const testFingerprint = SourceFileFingerprint(
  fileSize: 100 * 1024 * 1024,
  lastModifiedAt: 1,
);

EngineConfigurationReference engineConfigurationReference({
  String analysisId = 'analysis-1',
  int analysisRevision = 4,
  required String candidateId,
}) {
  return EngineConfigurationReference(
    analysisId: analysisId,
    analysisRevision: analysisRevision,
    candidateId: candidateId,
    selectionMode: 'manual',
    selectionJson: '{"mode":"manual"}',
  );
}

EngineAnalysisProjection engineAnalysisProjection({
  required String taskId,
  String analysisId = 'analysis-1',
  int revision = 4,
  int sequence = 10,
}) {
  return EngineAnalysisProjection(
    taskId: taskId,
    clientFileId: taskId,
    engineSessionId: 'session-1',
    analysisId: analysisId,
    revision: revision,
    schemaVersion: 'framelean.analysis-snapshot.v1',
    snapshotJson: '{}',
    validityStatus: 'valid',
    lastEventSequence: sequence,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(sequence),
  );
}

MediaTask videoTask({
  String id = 'task-1',
  String inputPath = '/videos/missing.mp4',
  TaskStatus status = TaskStatus.pending,
  VideoTaskConfig? config,
  int sortOrder = 0,
}) {
  return MediaTask(
    id: id,
    inputPath: inputPath,
    fileName: 'missing.mp4',
    mediaKind: MediaKind.video,
    purpose: TaskPurpose.compression,
    status: status,
    config: config ?? VideoTaskConfig.initial(),
    progress: 0,
    sortOrder: sortOrder,
    createdAt: 1,
  );
}

MediaTask readyVideoTask({required String id, required int sortOrder}) {
  return videoTask(
    id: id,
    inputPath: '/videos/$id.mp4',
    sortOrder: sortOrder,
  ).copyWith(
    sourceFileFingerprint: testFingerprint,
    analysisResult: MediaAnalysisResult(durationMs: 1000),
    analysisUpdatedAt: 1,
  );
}

MediaTaskConfig systemOutputVideoConfig({
  required String outputDirectory,
  required String outputFileName,
  required VideoCodec videoCodec,
}) {
  return MediaTaskConfig.fromVideoTaskConfig(
    VideoTaskConfig.initial().copyWith(
      outputDirectory: outputDirectory,
      outputFileName: outputFileName,
      videoCodec: videoCodec,
    ),
  ).copyWith(outputLocationMode: OutputLocationMode.system);
}

class FakeEngineGateway implements EngineLifecycleGateway {
  @override
  Stream<EngineWorkEvent> get events => const Stream.empty();

  @override
  Future<EngineOperationResult<EngineAnalysisCompletionDocument>> analyze(
    EngineAnalysisRequest request,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> close() async {}

  @override
  Future<EngineConnectionInfo> connect() async {
    return const EngineConnectionInfo(
      sessionId: 'session-1',
      protocolVersion: 1,
      engineVersion: 'test',
      heartbeatTimeout: Duration(seconds: 5),
      resumed: false,
    );
  }

  @override
  Future<EngineOperationResult<EngineAnalysisSnapshotDocument>>
  getAnalysisSnapshot(
    String analysisId, {
    EngineWorkPriority priority = EngineWorkPriority.foreground,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> ping() async {}

  @override
  Future<EngineOperationResult<EngineStateSnapshot>> getEngineSnapshot() async {
    return const EngineOperationResult(
      sessionId: 'session-1',
      requestId: 'snapshot-1',
      workId: 'snapshot-work-1',
      sequence: 1,
      value: EngineStateSnapshot(
        analysisQueueRevision: 0,
        analysisQueue: <EngineAnalysisQueueEntrySnapshot>[],
        executionLane: EngineExecutionLaneSnapshot(
          queueRevision: 0,
          active: null,
          normalWaiting: <EngineScheduledExecution>[],
          resumeStack: <EngineScheduledExecution>[],
        ),
        lastSequence: 0,
      ),
    );
  }

  @override
  Future<EngineOperationResult<EngineQueueOrderOutcome>> applyQueueOrder({
    required int orderRevision,
    required int expectedAnalysisQueueRevision,
    required int expectedExecutionQueueRevision,
    required List<String> orderedTaskIds,
  }) async {
    return EngineOperationResult(
      sessionId: 'session-1',
      requestId: 'order-$orderRevision',
      workId: 'order-work-$orderRevision',
      sequence: orderRevision,
      value: EngineQueueOrderApplied(
        orderRevision: orderRevision,
        analysisQueueRevision: expectedAnalysisQueueRevision,
        executionQueueRevision: expectedExecutionQueueRevision,
        analysisPositions: const <EngineQueuePosition>[],
        executionPositions: const <EngineQueuePosition>[],
      ),
    );
  }

  @override
  Future<EngineOperationResult<EngineExecutionSubmission>> submitExecution(
    EngineExecutionRequest request,
  ) {
    throw UnimplementedError();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeImportedMediaBatchPersistence
    implements ImportedMediaBatchPersistence {
  FakeImportedMediaBatchPersistence(this.tasks, this.folders);

  final FakeMediaTaskRepository tasks;
  final FakeTaskFolderRepository folders;

  @override
  Future<void> save({
    required List<MediaTask> tasks,
    required List<TaskFolder> folders,
  }) async {
    await this.tasks.insertTasks(tasks);
    for (final folder in folders) {
      await this.folders.saveFolder(folder);
    }
  }
}

class FakeWorkbenchOrderRevisionStore implements WorkbenchOrderRevisionStore {
  int revision = 0;

  @override
  Future<int> nextRevision() async => ++revision;
}

class FakeEngineAnalysisProjectionRepository
    implements EngineAnalysisProjectionRepository {
  FakeEngineAnalysisProjectionRepository(this.projection);

  EngineAnalysisProjection? projection;
  int loadCount = 0;
  void Function()? onSecondLoad;

  @override
  Future<void> deleteAll() async {
    projection = null;
  }

  @override
  Future<void> deleteByTaskId(String taskId) async {
    if (projection?.taskId == taskId) {
      projection = null;
    }
  }

  @override
  Future<EngineAnalysisProjection?> loadByTaskId(String taskId) async {
    loadCount += 1;
    if (loadCount == 2) {
      onSecondLoad?.call();
    }
    final current = projection;
    return current?.taskId == taskId ? current : null;
  }

  @override
  Future<void> upsert(EngineAnalysisProjection projection) async {
    this.projection = projection;
  }
}

class FakeMediaTaskRepository implements MediaTaskRepository {
  FakeMediaTaskRepository(List<MediaTask> initialTasks)
    : tasks = [...initialTasks];

  final List<MediaTask> tasks;
  int replaceAllCallCount = 0;
  int updateSortOrdersCallCount = 0;
  Object? updateSortOrdersError;
  int taskLoadCount = 0;
  void Function(String taskId)? onSecondTaskLoad;

  @override
  Future<void> deleteTaskById(String taskId) async {
    tasks.removeWhere((task) => task.id == taskId);
  }

  @override
  Future<List<MediaTask>> loadAllTasks() async {
    return [...tasks]..sort((first, second) {
      final order = first.sortOrder.compareTo(second.sortOrder);
      if (order != 0) {
        return order;
      }

      return first.createdAt.compareTo(second.createdAt);
    });
  }

  @override
  Future<void> replaceAllTasks(List<MediaTask> tasks) async {
    replaceAllCallCount += 1;
    this.tasks
      ..clear()
      ..addAll(tasks);
  }

  @override
  Future<void> updateTaskSortOrders(
    List<MediaTaskSortOrderUpdate> updates,
  ) async {
    updateSortOrdersCallCount += 1;
    final error = updateSortOrdersError;
    if (error != null) {
      throw error;
    }

    for (final update in updates) {
      final index = tasks.indexWhere((task) => task.id == update.taskId);
      if (index == -1) {
        continue;
      }

      tasks[index] = tasks[index].copyWith(sortOrder: update.sortOrder);
    }
  }

  @override
  Future<void> updateTaskFolderSortOrders(
    List<MediaTaskFolderSortOrderUpdate> updates,
  ) async {
    for (final update in updates) {
      final index = tasks.indexWhere((task) => task.id == update.taskId);
      if (index == -1) {
        continue;
      }

      tasks[index] = tasks[index].copyWith(
        folderSortOrder: update.folderSortOrder,
      );
    }
  }

  @override
  Future<void> saveTask(MediaTask task) async {
    replaceTaskForTest(task);
  }

  void replaceTaskForTest(MediaTask task) {
    final index = tasks.indexWhere((existingTask) {
      return existingTask.id == task.id;
    });
    if (index == -1) {
      tasks.add(task);
      return;
    }

    tasks[index] = task;
  }

  @override
  Future<MediaTask?> loadTaskById(String taskId) async {
    taskLoadCount += 1;
    if (taskLoadCount == 2) {
      onSecondTaskLoad?.call(taskId);
    }
    final index = tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return null;
    }
    return tasks[index];
  }

  @override
  Future<List<MediaTask>> loadTasksByIds(Iterable<String> taskIds) async {
    final idSet = taskIds.toSet();
    return tasks.where((task) => idSet.contains(task.id)).toList();
  }

  @override
  Future<void> insertTasks(List<MediaTask> newTasks) async {
    for (final task in newTasks) {
      final index = tasks.indexWhere((t) => t.id == task.id);
      if (index == -1) {
        tasks.add(task);
      } else {
        tasks[index] = task;
      }
    }
  }

  MediaTask taskById(String id) {
    return tasks.singleWhere((task) => task.id == id);
  }
}

class FakeTaskFolderRepository implements TaskFolderRepository {
  final List<TaskFolder> folders = [];

  @override
  Future<void> clearAllFolders() async {
    folders.clear();
  }

  @override
  Future<void> deleteFolderById(String folderId) async {
    folders.removeWhere((folder) => folder.id == folderId);
  }

  @override
  Future<List<TaskFolder>> loadAllFolders() async => [...folders];

  @override
  Future<void> saveFolder(TaskFolder folder) async {
    final index = folders.indexWhere((existing) => existing.id == folder.id);
    if (index == -1) {
      folders.add(folder);
      return;
    }
    folders[index] = folder;
  }

  @override
  Future<void> updateFolderSortOrders(
    List<TaskFolderSortOrderUpdate> updates,
  ) async {
    for (final update in updates) {
      final index = folders.indexWhere(
        (folder) => folder.id == update.folderId,
      );
      if (index == -1) {
        continue;
      }
      folders[index] = folders[index].copyWith(sortOrder: update.sortOrder);
    }
  }
}

class FakeSourceFileChecker implements SourceFileChecker {
  const FakeSourceFileChecker({required this.existingPaths});

  final Set<String> existingPaths;

  @override
  Future<bool> exists(String inputPath) async {
    return existingPaths.contains(inputPath);
  }
}

class FakeSourceFileFingerprintReader implements SourceFileFingerprintReader {
  FakeSourceFileFingerprintReader({this.fingerprint});

  final SourceFileFingerprint? fingerprint;
  final List<String> readPaths = [];

  @override
  Future<SourceFileFingerprint> read(String inputPath) async {
    readPaths.add(inputPath);
    final value = fingerprint;
    if (value != null) {
      return value;
    }

    throw StateError('不应该读取缺失源文件指纹: $inputPath');
  }
}

class FakeAppSettingsRepository implements AppSettingsRepository {
  FakeAppSettingsRepository(this.settings);

  AppSettings settings;

  @override
  Future<AppSettings> loadSettings() async {
    return settings;
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    this.settings = settings;
  }
}
