import 'package:framelean/application/services/app_maintenance/app_cache_cleaner.dart';

class PreviewAppCacheCleanupUseCase {
  const PreviewAppCacheCleanupUseCase({required this.cacheCleaner});

  final AppCacheCleaner cacheCleaner;

  Future<AppCacheCleanupPreview> call() {
    return cacheCleaner.preview();
  }
}
