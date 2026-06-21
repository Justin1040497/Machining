import 'dart:io';

import 'package:flutter/services.dart';
import 'package:framelean/app/constants.dart';

abstract final class WorkbenchWindowsPrivilege {
  static const MethodChannel _channel = MethodChannel(
    processControlChannel,
  );

  static Future<bool> isRunningElevated() async {
    if (!Platform.isWindows) {
      return false;
    }

    try {
      return await _channel.invokeMethod<bool>('isElevated') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> restartUnelevated() async {
    if (!Platform.isWindows) {
      return;
    }

    try {
      await _channel.invokeMethod<void>('restartUnelevated');
      exit(0);
    } on MissingPluginException {
      throw StateError('Windows 普通模式重启能力未注册');
    } on PlatformException catch (error) {
      final detail = error.message?.trim();
      if (detail == null || detail.isEmpty) {
        throw StateError('Windows 普通模式重启失败: ${error.code}');
      }
      throw StateError('Windows 普通模式重启失败: $detail');
    }
  }
}
