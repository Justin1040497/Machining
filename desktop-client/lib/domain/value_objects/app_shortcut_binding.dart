import 'package:framelean/domain/enums/app_shortcut_action.dart';

class AppShortcutBinding {
  const AppShortcutBinding({
    required this.key,
    this.primary = false,
    this.shift = false,
    this.alt = false,
  });

  final String key;
  final bool primary;
  final bool shift;
  final bool alt;

  String get signature =>
      '${primary ? 'primary+' : ''}'
      '${shift ? 'shift+' : ''}${alt ? 'alt+' : ''}${key.toLowerCase()}';

  @override
  bool operator ==(Object other) {
    return other is AppShortcutBinding &&
        other.key.toLowerCase() == key.toLowerCase() &&
        other.primary == primary &&
        other.shift == shift &&
        other.alt == alt;
  }

  @override
  int get hashCode => Object.hash(key.toLowerCase(), primary, shift, alt);
}

const defaultAppShortcutBindings = <AppShortcutAction, AppShortcutBinding>{
  AppShortcutAction.addFiles: AppShortcutBinding(key: 'KeyF'),
  AppShortcutAction.toggleWorkbenchExecution: AppShortcutBinding(key: 'Space'),
  AppShortcutAction.openSettings: AppShortcutBinding(
    key: 'Comma',
    primary: true,
  ),
  AppShortcutAction.openNotificationCenter: AppShortcutBinding(
    key: 'KeyN',
    primary: true,
    shift: true,
  ),
};
