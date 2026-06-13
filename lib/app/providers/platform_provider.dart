import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/services/platform/external_link_opener.dart';
import 'package:framelean/application/services/platform/file_revealer.dart';
import 'package:framelean/application/services/platform/file_selection_service.dart';
import 'package:framelean/application/services/platform/theme_preferences_cache.dart';
import 'package:framelean/infrastructure/services/platform/desktop_file_selection_service.dart';
import 'package:framelean/infrastructure/services/platform/local_external_link_opener.dart';
import 'package:framelean/infrastructure/services/platform/local_file_revealer.dart';
import 'package:framelean/infrastructure/services/platform/local_theme_preferences_cache.dart';

final externalLinkOpenerProvider = Provider<ExternalLinkOpener>((ref) {
  return const LocalExternalLinkOpener();
});

final fileRevealerProvider = Provider<FileRevealer>((ref) {
  return const LocalFileRevealer();
});

final fileSelectionServiceProvider = Provider<FileSelectionService>((ref) {
  return const DesktopFileSelectionService();
});

final themePreferencesCacheProvider = Provider<ThemePreferencesCache>((ref) {
  return const LocalThemePreferencesCache();
});
