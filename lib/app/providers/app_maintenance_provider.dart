import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/services/app_maintenance/app_cache_cleaner.dart';
import 'package:framelean/infrastructure/services/app_maintenance/local_app_cache_cleaner.dart';

// Application composition root for platform maintenance implementations.
final appCacheCleanerProvider = Provider<AppCacheCleaner>((ref) {
  return LocalAppCacheCleaner();
});
