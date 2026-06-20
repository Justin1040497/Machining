import 'dart:io';

import 'package:flutter/services.dart';
import 'package:framelean/app/shortcuts/app_shortcut_resolver.dart';
import 'package:framelean/domain/value_objects/app_shortcut_binding.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

HotKey? hotKeyForShortcutBinding(
  AppShortcutBinding binding, {
  HotKeyScope scope = HotKeyScope.inapp,
}) {
  final key = logicalKeyForShortcut(binding);
  if (key == null) {
    return null;
  }

  return HotKey(
    key: key,
    modifiers: hotKeyModifiersForShortcutBinding(binding),
    scope: scope,
  );
}

List<HotKeyModifier> hotKeyModifiersForShortcutBinding(
  AppShortcutBinding binding,
) {
  return [
    if (binding.primary)
      Platform.isMacOS ? HotKeyModifier.meta : HotKeyModifier.control,
    if (binding.shift) HotKeyModifier.shift,
    if (binding.alt) HotKeyModifier.alt,
  ];
}

AppShortcutBinding shortcutBindingFromHotKey(HotKey hotKey) {
  final modifiers = hotKey.modifiers ?? const <HotKeyModifier>[];
  final primaryModifier = Platform.isMacOS
      ? HotKeyModifier.meta
      : HotKeyModifier.control;

  return AppShortcutBinding(
    key: '0x${hotKey.logicalKey.keyId.toRadixString(16)}',
    primary: modifiers.contains(primaryModifier),
    shift: modifiers.contains(HotKeyModifier.shift),
    alt: modifiers.contains(HotKeyModifier.alt),
  );
}

bool hotKeyIsOnlyModifier(HotKey hotKey) {
  final physicalKey = hotKey.physicalKey;
  return HotKeyModifier.values.any(
    (modifier) => modifier.physicalKeys.contains(physicalKey),
  );
}

HotKey fixedInAppHotKey(LogicalKeyboardKey key) {
  return HotKey(key: key, scope: HotKeyScope.inapp);
}
