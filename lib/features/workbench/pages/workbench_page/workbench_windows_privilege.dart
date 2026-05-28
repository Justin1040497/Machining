import 'dart:io';

import 'package:flutter/services.dart';

abstract final class WorkbenchWindowsPrivilege {
  static const MethodChannel _channel = MethodChannel(
    'framelean/process_control',
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
}
