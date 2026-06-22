import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/app/providers/app_update_provider.dart';
import 'package:framelean/application/services/app_maintenance/app_cache_cleaner.dart';
import 'package:framelean/infrastructure/services/app_maintenance/local_app_cache_cleaner.dart';
import 'package:path_provider/path_provider.dart';

// Application composition root for platform maintenance implementations.
final appCacheCleanerProvider = Provider<AppCacheCleaner>((ref) {
  return LocalAppCacheCleaner(
    supportDirectoryProvider: getApplicationSupportDirectory,
    excludeFilePathsProvider: () async {
      final updateState = ref.watch(appUpdateProvider).asData?.value;
      final path = updateState?.downloadedFilePath;
      return path != null ? [path] : const [];
    },
  );
});
