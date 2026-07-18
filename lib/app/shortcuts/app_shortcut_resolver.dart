import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:framelean/domain/library.dart';

LogicalKeyboardKey? logicalKeyForShortcut(AppShortcutBinding binding) {
  final knownKey = switch (binding.key.toLowerCase()) {
    'keyf' => LogicalKeyboardKey.keyF,
    'keyn' => LogicalKeyboardKey.keyN,
    'space' => LogicalKeyboardKey.space,
    'comma' => LogicalKeyboardKey.comma,
    _ => null,
  };
  if (knownKey != null) return knownKey;

  final rawKeyId = binding.key.toLowerCase().startsWith('0x')
      ? int.tryParse(binding.key.substring(2), radix: 16)
      : int.tryParse(binding.key);
  return rawKeyId == null ? null : LogicalKeyboardKey(rawKeyId);
}

SingleActivator? activatorForShortcut(AppShortcutBinding binding) {
  final key = logicalKeyForShortcut(binding);
  if (key == null) return null;
  return SingleActivator(
    key,
    meta: binding.primary && Platform.isMacOS,
    control: binding.primary && !Platform.isMacOS,
    shift: binding.shift,
    alt: binding.alt,
    includeRepeats: false,
  );
}

AppShortcutBinding? shortcutBindingFromKeyEvent(KeyEvent event) {
  if (event is! KeyDownEvent || _isModifierKey(event.logicalKey)) return null;
  final keyboard = HardwareKeyboard.instance;
  return AppShortcutBinding(
    key: '0x${event.logicalKey.keyId.toRadixString(16)}',
    primary: Platform.isMacOS
        ? keyboard.isMetaPressed
        : keyboard.isControlPressed,
    shift: keyboard.isShiftPressed,
    alt: keyboard.isAltPressed,
  );
}

String shortcutBindingLabel(AppShortcutBinding binding) {
  final key = logicalKeyForShortcut(binding);
  final parts = <String>[
    if (binding.primary) Platform.isMacOS ? '⌘' : 'Ctrl',
    if (binding.shift) 'Shift',
    if (binding.alt) Platform.isMacOS ? '⌥' : 'Alt',
    _logicalKeyLabel(key),
  ];
  return Platform.isMacOS ? parts.join(' ') : parts.join(' + ');
}

String _logicalKeyLabel(LogicalKeyboardKey? key) {
  if (key == null) return '未知按键';
  if (key == LogicalKeyboardKey.space) return 'Space';
  if (key == LogicalKeyboardKey.comma) return ',';
  return key.keyLabel.isEmpty ? key.debugName ?? '未知按键' : key.keyLabel;
}

bool _isModifierKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.controlLeft ||
      key == LogicalKeyboardKey.controlRight ||
      key == LogicalKeyboardKey.metaLeft ||
      key == LogicalKeyboardKey.metaRight ||
      key == LogicalKeyboardKey.shiftLeft ||
      key == LogicalKeyboardKey.shiftRight ||
      key == LogicalKeyboardKey.altLeft ||
      key == LogicalKeyboardKey.altRight;
}
