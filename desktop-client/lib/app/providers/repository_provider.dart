import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/infrastructure/library.dart';
import 'package:framelean/app/providers/database_provider.dart';

/// 应用设置数据库操作管理状态
/// 这里最好暴露抽象类给外面
final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  /// 先拿到数据库
  final database = ref.watch(appDatabaseProvider);

  /// 创建并返回实例
  return DriftAppSettingsRepository(database);
});

/// 任务数据库操作管理状态
final mediaTaskRepositoryProvider = Provider<MediaTaskRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return DriftMediaTaskRepository(database);
});

final importedMediaBatchPersistenceProvider =
    Provider<ImportedMediaBatchPersistence>((ref) {
      return DriftImportedMediaBatchPersistence(ref.watch(appDatabaseProvider));
    });

final taskFolderArrangementPersistenceProvider =
    Provider<TaskFolderArrangementPersistence>((ref) {
      return DriftTaskFolderArrangementPersistence(
        ref.watch(appDatabaseProvider),
      );
    });

final workbenchOrderRevisionStoreProvider =
    Provider<WorkbenchOrderRevisionStore>((ref) {
      return DriftWorkbenchOrderRevisionStore(ref.watch(appDatabaseProvider));
    });

final engineAnalysisProjectionRepositoryProvider =
    Provider<EngineAnalysisProjectionRepository>((ref) {
      final database = ref.watch(appDatabaseProvider);
      return DriftEngineAnalysisProjectionRepository(database);
    });

final taskFolderRepositoryProvider = Provider<TaskFolderRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  return DriftTaskFolderRepository(database);
});

final taskArrangementRevisionProvider =
    NotifierProvider<TaskArrangementRevisionNotifier, int>(
      TaskArrangementRevisionNotifier.new,
    );

final class TaskArrangementRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void advance() {
    state += 1;
  }
}

final taskFolderListProvider = FutureProvider<List<TaskFolder>>((ref) {
  ref.watch(taskArrangementRevisionProvider);
  return ref.watch(taskFolderRepositoryProvider).loadAllFolders();
});
