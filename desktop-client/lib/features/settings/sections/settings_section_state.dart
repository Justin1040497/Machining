part of '../pages/app_settings_page.dart';

extension _AppSettingsViewSectionState on _AppSettingsViewState {
  void closePage() {
    _revertCurrentSectionIfDirty();
    widget.onClose?.call();
  }

  void _revertCurrentSectionIfDirty() {
    if (!isSectionDirty(selectedSection)) return;
    _revertSection(selectedSection);
  }

  // ------- dirty detection -------

  bool isSectionDirty(_SettingsSection section) {
    return switch (section) {
      _SettingsSection.app => _isAppSectionDirty,
      _SettingsSection.notifications => _isNotificationSectionDirty,
      _SettingsSection.shortcuts => _isShortcutSectionDirty,
      _SettingsSection.about => false,
      _SettingsSection.video => _isVideoSectionDirty,
      _SettingsSection.image => _isImageSectionDirty,
      _SettingsSection.audio => _isAudioSectionDirty,
      _SettingsSection.output => _isOutputSectionDirty,
    };
  }

  bool get _isAppSectionDirty =>
      themeMode != savedSettings.themeMode ||
      completionSound != savedSettings.taskCompletionSound ||
      hideNotificationBadge != savedSettings.hideNotificationBadge ||
      closeBehavior != savedSettings.closeBehavior ||
      folderImportScanDepth != savedSettings.folderImportScanDepth;

  bool get _isNotificationSectionDirty =>
      !_mapsEqual(notificationPolicies, savedSettings.notificationPolicies);

  bool get _isShortcutSectionDirty =>
      !_mapsEqual(shortcutBindings, savedSettings.shortcutBindings);

  bool get _isVideoSectionDirty {
    final current = videoConfig;
    final savedConfig = _withAllMediaDefaults(savedSettings.defaultMediaConfig);
    final savedVideo = savedConfig.video;
    if (savedVideo == null) return false;
    return defaultMediaConfig.compressionMode != savedConfig.compressionMode ||
        current.outputFormat != savedVideo.outputFormat ||
        current.keepOriginalOutputFormat !=
            savedVideo.keepOriginalOutputFormat ||
        current.videoCodec != savedVideo.videoCodec ||
        current.resolutionPreset != savedVideo.resolutionPreset ||
        current.smartPreset != savedVideo.smartPreset ||
        current.preserveMetadata != savedVideo.preserveMetadata;
  }

  bool get _isImageSectionDirty {
    final current = imageConfig;
    final savedImage = _withAllMediaDefaults(
      savedSettings.defaultMediaConfig,
    ).image;
    if (savedImage == null) return false;
    return current.outputFormat != savedImage.outputFormat ||
        current.keepOriginalOutputFormat !=
            savedImage.keepOriginalOutputFormat ||
        current.imageQuality != savedImage.imageQuality ||
        current.resizePreset != savedImage.resizePreset ||
        current.preserveMetadata != savedImage.preserveMetadata;
  }

  bool get _isAudioSectionDirty {
    final current = audioConfig;
    final savedAudio = _withAllMediaDefaults(
      savedSettings.defaultMediaConfig,
    ).audio;
    if (savedAudio == null) return false;
    return current.outputFormat != savedAudio.outputFormat ||
        current.keepOriginalOutputFormat !=
            savedAudio.keepOriginalOutputFormat ||
        current.bitratePreset != savedAudio.bitratePreset ||
        current.sampleRate != savedAudio.sampleRate ||
        current.channels != savedAudio.channels ||
        current.preserveMetadata != savedAudio.preserveMetadata;
  }

  bool get _isOutputSectionDirty {
    if (saveOutputToSourceDirectory !=
        savedSettings.saveOutputToSourceDirectory) {
      return true;
    }
    if (outputFileNameTemplateController.text.trim() !=
        savedSettings.defaultOutputFileNameTemplate) {
      return true;
    }
    if (!saveOutputToSourceDirectory) {
      final currentDir = outputDirectoryController.text.trim();
      final savedDir = savedSettings.defaultOutputDirectory ?? '';
      if (currentDir != savedDir) {
        return true;
      }
    }
    return false;
  }

  // ------- per-section revert -------

  void _revertSection(_SettingsSection section) {
    switch (section) {
      case _SettingsSection.app:
        _revertAppSection();
      case _SettingsSection.notifications:
        updateViewState(() {
          notificationPolicies = Map.of(savedSettings.notificationPolicies);
        });
      case _SettingsSection.shortcuts:
        updateViewState(() {
          shortcutBindings = Map.of(savedSettings.shortcutBindings);
        });
      case _SettingsSection.video:
        _revertVideoSection();
      case _SettingsSection.image:
        _revertImageSection();
      case _SettingsSection.audio:
        _revertAudioSection();
      case _SettingsSection.output:
        _revertOutputSection();
      case _SettingsSection.about:
        break;
    }
  }

  void _revertAppSection() {
    updateViewState(() {
      themeMode = savedSettings.themeMode;
      completionSound = savedSettings.taskCompletionSound;
      hideNotificationBadge = savedSettings.hideNotificationBadge;
      folderImportScanDepth = savedSettings.folderImportScanDepth;
      closeBehavior = savedSettings.closeBehavior;
    });
  }

  void _revertVideoSection() {
    updateViewState(() {
      defaultMediaConfig = _withAllMediaDefaults(
        savedSettings.defaultMediaConfig,
      );
    });
  }

  void _revertImageSection() {
    final savedImage = _withAllMediaDefaults(
      savedSettings.defaultMediaConfig,
    ).image;
    if (savedImage == null) return;
    updateImageConfig(savedImage);
  }

  void _revertAudioSection() {
    final savedAudio = _withAllMediaDefaults(
      savedSettings.defaultMediaConfig,
    ).audio;
    if (savedAudio == null) return;
    updateAudioConfig(savedAudio);
  }

  void _revertOutputSection() {
    updateViewState(() {
      saveOutputToSourceDirectory = savedSettings.saveOutputToSourceDirectory;
      outputFileNameTemplateController.text =
          savedSettings.defaultOutputFileNameTemplate;
      outputDirectoryController.text =
          savedSettings.defaultOutputDirectory ??
          widget.fallbackDefaultDirectory;
    });
  }

  // ------- per-section save -------

  Future<void> _saveSection(_SettingsSection section) async {
    if (savingSection != null) return;
    updateViewState(() => savingSection = section);
    try {
      final updatedSettings = _buildSettingsForSection(section);
      await widget.onSave(updatedSettings, section.saveTarget);
      if (!mounted) return;
      updateViewState(() {
        savedSettings = updatedSettings;
        if (section == _SettingsSection.output) {
          outputFileNameTemplateController.text =
              updatedSettings.defaultOutputFileNameTemplate;
        }
      });
    } on Object {
      // The global notification manager records and presents the failure.
    } finally {
      if (mounted) {
        updateViewState(() => savingSection = null);
      }
    }
  }

  AppSettings _buildSettingsForSection(_SettingsSection section) {
    final base = savedSettings;
    switch (section) {
      case _SettingsSection.app:
        return base.copyWith(
          themeMode: themeMode,
          taskCompletionSound: completionSound,
          hideNotificationBadge: hideNotificationBadge,
          folderImportScanDepth: folderImportScanDepth,
          closeBehavior: closeBehavior,
        );
      case _SettingsSection.notifications:
        return base.copyWith(notificationPolicies: notificationPolicies);
      case _SettingsSection.shortcuts:
        return base.copyWith(shortcutBindings: shortcutBindings);
      case _SettingsSection.video:
        final video = videoConfig;
        final updatedConfig = defaultMediaConfig.copyWith(video: video);
        return base.copyWith(
          defaultMediaConfig: updatedConfig,
          defaultOutputVideoCodec: video.videoCodec,
          defaultSmartPreset: video.smartPreset ?? SmartCompressionPreset.chat,
        );
      case _SettingsSection.image:
        final updatedConfig = savedSettings.defaultMediaConfig.copyWith(
          image: imageConfig,
        );
        return base.copyWith(defaultMediaConfig: updatedConfig);
      case _SettingsSection.audio:
        final updatedConfig = savedSettings.defaultMediaConfig.copyWith(
          audio: audioConfig,
        );
        return base.copyWith(defaultMediaConfig: updatedConfig);
      case _SettingsSection.output:
        final outputDirectory = outputDirectoryController.text.trim();
        return base.copyWith(
          saveOutputToSourceDirectory: saveOutputToSourceDirectory,
          defaultOutputDirectory: saveOutputToSourceDirectory
              ? null
              : outputDirectory.isEmpty
              ? null
              : outputDirectory,
          defaultOutputFileNameTemplate: outputFileNameTemplateController.text,
        );
      case _SettingsSection.about:
        return base;
    }
  }
}

enum _SettingsSection {
  app('应用设置', Icons.grid_view_rounded),
  notifications('通知设置', Icons.notifications_none_rounded),
  shortcuts('快捷键', Icons.keyboard_alt_outlined),
  about('关于', Icons.info_outline_rounded),
  video('视频任务', Icons.ondemand_video_rounded),
  image('图片任务', Icons.image_outlined),
  audio('音频任务', Icons.album_outlined),
  output('输出配置', Icons.output_rounded);

  const _SettingsSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

extension _SettingsSectionSaveTarget on _SettingsSection {
  AppSettingsSaveTarget get saveTarget {
    return switch (this) {
      _SettingsSection.app => AppSettingsSaveTarget.application,
      _SettingsSection.notifications => AppSettingsSaveTarget.notifications,
      _SettingsSection.shortcuts => AppSettingsSaveTarget.shortcuts,
      _SettingsSection.video => AppSettingsSaveTarget.videoTask,
      _SettingsSection.image => AppSettingsSaveTarget.imageTask,
      _SettingsSection.audio => AppSettingsSaveTarget.audioTask,
      _SettingsSection.output => AppSettingsSaveTarget.output,
      _SettingsSection.about => throw StateError('关于分区没有可保存的设置'),
    };
  }
}

bool _mapsEqual<K, V>(Map<K, V> left, Map<K, V> right) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) return false;
  }
  return true;
}

extension _TaskCompletionSoundSettingsLabel on TaskCompletionSound {
  String get settingsLabel {
    return switch (this) {
      TaskCompletionSound.none => '不通知',
      TaskCompletionSound.cleanSuccess => '清脆完成',
      TaskCompletionSound.mechanicalKey => '轻触机械',
      TaskCompletionSound.originalSoftA => '柔云提示',
      TaskCompletionSound.originalSoftB => '轻柔回响',
      TaskCompletionSound.servoConfirm => '伺服确认',
    };
  }
}

extension _AppThemeModeSettingsLabel on AppThemeMode {
  String get settingsLabel {
    return switch (this) {
      AppThemeMode.system => '跟随系统',
      AppThemeMode.light => '浅色',
      AppThemeMode.dark => '深色',
    };
  }
}

extension _AppCloseBehaviorSettingsLabel on AppCloseBehavior {
  String get settingsLabel => switch (this) {
    AppCloseBehavior.background => '最小化到后台',
    AppCloseBehavior.quit => '退出应用程序',
  };
}

extension _NotificationDeliveryModeSettingsLabel on NotificationDeliveryMode {
  String get settingsLabel => switch (this) {
    NotificationDeliveryMode.persistent => '通知',
    NotificationDeliveryMode.transient => '临时通知',
    NotificationDeliveryMode.disabled => '不通知',
  };
}

extension _NotificationEventTypeSettingsLabel on NotificationEventType {
  String get settingsLabel => switch (this) {
    NotificationEventType.taskCompleted => '任务完成',
    NotificationEventType.taskFailed => '任务失败',
    NotificationEventType.updateAvailable => '发现应用更新',
    NotificationEventType.updateFailed => '更新失败',
    NotificationEventType.settingsSaveSucceeded => '设置保存成功',
    NotificationEventType.settingsSaveFailed => '设置保存失败',
    NotificationEventType.workbenchOperationSucceeded => '工作台操作成功',
    NotificationEventType.workbenchOperationFailed => '工作台操作失败',
    NotificationEventType.interactionHint => '普通交互提示',
    NotificationEventType.clipboardOperation => '复制与剪贴板操作',
  };
}

extension _AppShortcutActionSettingsLabel on AppShortcutAction {
  String get settingsLabel => switch (this) {
    AppShortcutAction.addFiles => '添加文件或文件夹',
    AppShortcutAction.toggleWorkbenchExecution => '开始 / 暂停全部任务',
    AppShortcutAction.openSettings => '打开设置',
    AppShortcutAction.openNotificationCenter => '打开通知中心',
  };
}

MediaTaskConfig _withAllMediaDefaults(MediaTaskConfig config) {
  final fallback = MediaTaskConfig.initialDefaults();
  return config.copyWith(
    video: config.video ?? fallback.video,
    image: config.image ?? fallback.image,
    audio: config.audio ?? fallback.audio,
  );
}

String formatBytes(int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  final fractionDigits = value >= 10 || unitIndex == 0 ? 0 : 1;
  return '${value.toStringAsFixed(fractionDigits)} ${units[unitIndex]}';
}
