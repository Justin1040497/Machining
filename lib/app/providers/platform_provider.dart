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

/// Enables OS-level startup behavior such as hotkeys, tray/window listeners,
/// update auto-checks, and local startup cleanup.
///
/// Integration tests override this to keep app-launch smoke tests isolated from
/// the developer machine while production keeps the default behavior.
final appRuntimeEffectsEnabledProvider = Provider<bool>((ref) {
  return true;
});
