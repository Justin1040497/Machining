part of '../app_settings_page.dart';

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
      _SettingsSection.about => false,
      _SettingsSection.video => _isVideoSectionDirty,
      _SettingsSection.image => _isImageSectionDirty,
      _SettingsSection.audio => _isAudioSectionDirty,
      _SettingsSection.output => _isOutputSectionDirty,
      _SettingsSection.encoder => _isEncoderSectionDirty,
    };
  }

  bool get _isAppSectionDirty => themeMode != savedSettings.themeMode;

  bool get _isVideoSectionDirty {
    final current = videoConfig;
    final savedVideo = _withAllMediaDefaults(
      savedSettings.defaultMediaConfig,
    ).video;
    if (savedVideo == null) return false;
    return current.outputFormat != savedVideo.outputFormat ||
        current.videoCodec != savedVideo.videoCodec ||
        current.resolutionPreset != savedVideo.resolutionPreset ||
        current.smartPreset != savedVideo.smartPreset;
  }

  bool get _isImageSectionDirty {
    final current = imageConfig;
    final savedImage = _withAllMediaDefaults(
      savedSettings.defaultMediaConfig,
    ).image;
    if (savedImage == null) return false;
    return current.outputFormat != savedImage.outputFormat ||
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
        current.bitratePreset != savedAudio.bitratePreset ||
        current.sampleRate != savedAudio.sampleRate ||
        current.channels != savedAudio.channels;
  }

  bool get _isOutputSectionDirty {
    if (saveOutputToSourceDirectory !=
        savedSettings.saveOutputToSourceDirectory) {
      return true;
    }
    if (outputFileNameTemplate != savedSettings.defaultOutputFileNameTemplate) {
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

  bool get _isEncoderSectionDirty {
    final currentFfmpeg = ffmpegPathController.text.trim();
    final savedFfmpeg = savedSettings.customFfmpegPath ?? '';
    if (currentFfmpeg != savedFfmpeg) return true;

    final currentFfprobe = ffprobePathController.text.trim();
    final savedFfprobe = savedSettings.customFfprobePath ?? '';
    if (currentFfprobe != savedFfprobe) return true;

    return false;
  }

  // ------- per-section revert -------

  void _revertSection(_SettingsSection section) {
    switch (section) {
      case _SettingsSection.app:
        _revertAppSection();
      case _SettingsSection.video:
        _revertVideoSection();
      case _SettingsSection.image:
        _revertImageSection();
      case _SettingsSection.audio:
        _revertAudioSection();
      case _SettingsSection.output:
        _revertOutputSection();
      case _SettingsSection.encoder:
        _revertEncoderSection();
      case _SettingsSection.about:
        break;
    }
  }

  void _revertAppSection() {
    updateViewState(() => themeMode = savedSettings.themeMode);
  }

  void _revertVideoSection() {
    final savedVideo = _withAllMediaDefaults(
      savedSettings.defaultMediaConfig,
    ).video;
    if (savedVideo == null) return;
    updateVideoConfig(savedVideo);
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
      outputFileNameTemplate = savedSettings.defaultOutputFileNameTemplate;
      outputDirectoryController.text =
          savedSettings.defaultOutputDirectory ??
          widget.fallbackDefaultDirectory;
    });
  }

  void _revertEncoderSection() {
    updateViewState(() {
      ffmpegPathController.text = savedSettings.customFfmpegPath ?? '';
      ffprobePathController.text = savedSettings.customFfprobePath ?? '';
    });
  }

  // ------- per-section save -------

  Future<void> _saveSection(_SettingsSection section) async {
    if (savingSection != null) return;
    updateViewState(() => savingSection = section);
    try {
      final updatedSettings = _buildSettingsForSection(section);
      await widget.onSave(updatedSettings);
      if (!mounted) return;
      updateViewState(() => savedSettings = updatedSettings);
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
        return base.copyWith(themeMode: themeMode);
      case _SettingsSection.video:
        final video = videoConfig;
        final updatedConfig = savedSettings.defaultMediaConfig.copyWith(
          video: video,
        );
        return base.copyWith(
          defaultMediaConfig: updatedConfig,
          defaultOutputVideoCodec: video.videoCodec,
          defaultSmartPreset:
              video.smartPreset ?? SmartCompressionPreset.balanced,
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
          defaultOutputFileNameTemplate: outputFileNameTemplate,
        );
      case _SettingsSection.encoder:
        final ffmpegPath = ffmpegPathController.text.trim();
        final ffprobePath = ffprobePathController.text.trim();
        return base.copyWith(
          customFfmpegPath: ffmpegPath.isEmpty ? null : ffmpegPath,
          customFfprobePath: ffprobePath.isEmpty ? null : ffprobePath,
        );
      case _SettingsSection.about:
        return base;
    }
  }
}

enum _CompletionSoundOption {
  none;

  String get label => switch (this) {
    _CompletionSoundOption.none => '不通知',
  };
}

enum _SettingsSection {
  app('应用设置', Icons.grid_view_rounded),
  about('关于', Icons.info_outline_rounded),
  video('视频任务', Icons.ondemand_video_rounded),
  image('图片任务', Icons.image_outlined),
  audio('音频任务', Icons.album_outlined),
  output('输出配置', Icons.output_rounded),
  encoder('编码器配置', Icons.build_rounded);

  const _SettingsSection(this.label, this.icon);

  final String label;
  final IconData icon;
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
