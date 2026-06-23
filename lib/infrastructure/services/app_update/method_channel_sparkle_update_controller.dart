import 'dart:io';

import 'package:flutter/services.dart';
import 'package:framelean/app/library.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';

class MethodChannelSparkleUpdateController implements SparkleUpdateController {
  MethodChannelSparkleUpdateController();

  static const _channel = MethodChannel(sparkleUpdateChannel);

  void setRestartPreparationHandler(Future<void> Function() handler) {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'prepareForUpdateRestart') {
        throw MissingPluginException(
          'Unknown Sparkle callback: ${call.method}',
        );
      }
      await handler();
    });
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
  }

  @override
  Future<void> checkForUpdates(EnterpriseUpdateConfig config) async {
    if (!Platform.isMacOS) {
      return;
    }
    await _channel.invokeMethod<void>('checkForUpdates', _arguments(config));
  }

  @override
  Future<void> checkForUpdateInformation(EnterpriseUpdateConfig config) async {
    if (!Platform.isMacOS) {
      return;
    }
    await _channel.invokeMethod<void>(
      'checkForUpdateInformation',
      _arguments(config),
    );
  }

  @override
  Future<SparkleUpdatePolicyStatus> getUpdatePolicyStatus(
    EnterpriseUpdateConfig config,
  ) async {
    if (!Platform.isMacOS) {
      return const SparkleUpdatePolicyStatus(
        available: false,
        automaticChecksEnabled: false,
        appcastUrl: '',
      );
    }
    final result = await _channel.invokeMapMethod<String, Object?>(
      'getUpdatePolicyStatus',
      _arguments(config),
    );
    return SparkleUpdatePolicyStatus(
      available: result?['available'] == true,
      automaticChecksEnabled: result?['automaticChecksEnabled'] == true,
      appcastUrl: result?['appcastUrl'] as String? ?? '',
    );
  }

  Map<String, Object?> _arguments(EnterpriseUpdateConfig config) {
    return {
      'appcastUrl': config.macosAppcastUrl,
      'allowAutomaticChecks': config.allowAutomaticChecks,
      'allowInAppInstall': config.allowInAppInstall,
    };
  }
}
