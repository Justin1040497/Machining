import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/app/providers/repository_provider.dart';
import 'package:framelean/infrastructure/library.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

final fengineExecutableLocatorProvider =
    Provider<LocalFEngineExecutableLocator>((ref) {
      return LocalFEngineExecutableLocator();
    });

final engineGatewayProvider = FutureProvider<EngineLifecycleGateway>((
  ref,
) async {
  final executablePath = await ref
      .watch(fengineExecutableLocatorProvider)
      .resolve();
  final supportDirectory = await getApplicationSupportDirectory();
  final gateway = LocalFEngineGateway(
    executablePath: executablePath,
    snapshotDirectory: path.join(
      supportDirectory.path,
      'engine',
      'analysis-snapshots',
    ),
    clientVersion: FrameLeanBuildInfo.currentVersionLabel,
  );
  ref.onDispose(() {
    unawaited(gateway.close());
  });
  return gateway;
});

final engineTaskProjectionProvider = FutureProvider.autoDispose
    .family<EngineAnalysisProjection?, String>((ref, taskId) {
      return ref
          .watch(engineAnalysisProjectionRepositoryProvider)
          .loadByTaskId(taskId);
    });

final engineLifecycleCoordinatorProvider =
    FutureProvider<EngineLifecycleCoordinator>((ref) async {
      final gatewayFuture = ref.watch(engineGatewayProvider.future);
      final taskRepository = ref.watch(mediaTaskRepositoryProvider);
      final projectionRepository = ref.watch(
        engineAnalysisProjectionRepositoryProvider,
      );
      EngineLifecycleCoordinator? coordinator;
      var disposed = false;
      ref.onDispose(() {
        disposed = true;
        if (coordinator != null) {
          unawaited(coordinator.close());
        }
      });

      coordinator = EngineLifecycleCoordinator(
        gateway: await gatewayFuture,
        taskRepository: taskRepository,
        projectionRepository: projectionRepository,
        onAnalysisRecovered: (taskId) async {
          final changed = await ReconcileAnalyzedAutomaticTaskFoldersUseCase(
            mediaTaskRepository: taskRepository,
            taskFolderRepository: ref.read(taskFolderRepositoryProvider),
            persistence: ref.read(taskFolderArrangementPersistenceProvider),
          ).call();
          if (!disposed && changed) {
            ref.read(taskArrangementRevisionProvider.notifier).advance();
          }
        },
        onProjectionChanged: (taskId) {
          if (!disposed) {
            ref.invalidate(engineTaskProjectionProvider(taskId));
          }
        },
      );
      if (disposed) {
        return coordinator;
      }
      await coordinator.start();
      if (disposed) {
        unawaited(coordinator.close());
      }
      return coordinator;
    });
