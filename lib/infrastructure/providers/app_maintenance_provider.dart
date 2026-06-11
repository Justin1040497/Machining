import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/services/app_maintenance/app_cache_cleaner.dart';
import 'package:framelean/application/services/app_maintenance/app_uninstaller.dart';
import 'package:framelean/infrastructure/services/app_maintenance/local_app_cache_cleaner.dart';
import 'package:framelean/infrastructure/services/app_maintenance/noop_app_uninstaller.dart';
import 'package:framelean/infrastructure/services/app_maintenance/windows_clean_app_uninstaller.dart';

final appCacheCleanerProvider = Provider<AppCacheCleaner>((ref) {
  return LocalAppCacheCleaner();
});

final appUninstallerProvider = Provider<AppUninstaller>((ref) {
  if (Platform.isWindows) {
    return WindowsCleanAppUninstaller();
  }

  return const NoopAppUninstaller(reason: 'macOS 不提供应用内卸载入口，请使用随包脚本或手动删除应用');
});
