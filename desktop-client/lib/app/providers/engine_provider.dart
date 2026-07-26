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
      final coordinator = EngineLifecycleCoordinator(
        gateway: await ref.watch(engineGatewayProvider.future),
        taskRepository: ref.watch(mediaTaskRepositoryProvider),
        projectionRepository: ref.watch(
          engineAnalysisProjectionRepositoryProvider,
        ),
        onProjectionChanged: (taskId) {
          ref.invalidate(engineTaskProjectionProvider(taskId));
        },
      );
      await coordinator.start();
      ref.onDispose(() {
        unawaited(coordinator.close());
      });
      return coordinator;
    });
