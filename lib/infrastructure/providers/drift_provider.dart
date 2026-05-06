import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:machining/application/repositories/app_settings_repository.dart';
import 'package:machining/application/repositories/media_task_repository.dart';
import 'package:machining/application/services/media_kind_resolver.dart';
import 'package:machining/application/services/source_file_fingerprint_reader.dart';
import 'package:machining/application/services/source_file_checker.dart';
import 'package:machining/infrastructure/providers/database_provider.dart';
import 'package:machining/infrastructure/repositories/drift_app_settings_repository.dart';
import 'package:machining/infrastructure/repositories/drift_media_task_repository.dart';
import 'package:machining/infrastructure/services/extension_media_kind_resolver.dart';
import 'package:machining/infrastructure/services/local_source_file_fingerprint_reader.dart';
import 'package:machining/infrastructure/services/local_source_file_checker.dart';

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

/// 媒体类型识别服务
final mediaKindResolverProvider = Provider<MediaKindResolver>((ref) {
  return ExtensionMediaKindResolver();
});

/// 源文件存在检查服务
final sourceFileCheckerProvider = Provider<SourceFileChecker>((ref) {
  return LocalSourceFileChecker();
});

/// 源文件快速指纹读取服务
final sourceFileFingerprintReaderProvider =
    Provider<SourceFileFingerprintReader>((ref) {
      return LocalSourceFileFingerprintReader();
    });
