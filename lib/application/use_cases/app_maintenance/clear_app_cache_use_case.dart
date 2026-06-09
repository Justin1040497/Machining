import 'package:framelean/application/services/app_maintenance/app_cache_cleaner.dart';

class ClearAppCacheUseCase {
  const ClearAppCacheUseCase({required this.cacheCleaner});

  final AppCacheCleaner cacheCleaner;

  Future<AppCacheCleanupResult> call() {
    return cacheCleaner.clear();
  }
}
