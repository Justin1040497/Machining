import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/infrastructure/library.dart';

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
