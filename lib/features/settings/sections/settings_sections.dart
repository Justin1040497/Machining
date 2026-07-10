part of '../pages/app_settings_page.dart';

extension _AppSettingsViewSections on _AppSettingsViewState {
  Widget buildSelectedSection() {
    return switch (selectedSection) {
      _SettingsSection.app => buildAppSettingsSection(),
      _SettingsSection.notifications => buildNotificationSettingsSection(),
      _SettingsSection.shortcuts => buildShortcutSettingsSection(),
      _SettingsSection.about => buildAboutSection(),
      _SettingsSection.video => buildVideoSection(),
      _SettingsSection.image => buildImageSection(),
      _SettingsSection.audio => buildAudioSection(),
      _SettingsSection.output => buildOutputSection(),
      _SettingsSection.encoder => buildEncoderSection(),
    };
  }

  Widget buildAppSettingsSection() {
    return _SettingsForm(
      title: '应用设置',
      children: [
        _SettingsDropdown<AppThemeMode>(
          label: '应用主题颜色',
          value: themeMode,
          values: AppThemeMode.values,
          itemLabel: (value) => value.settingsLabel,
          onChanged: (value) {
            if (value == null) {
              return;
            }
            updateViewState(() => themeMode = value);
          },
        ),
        const SizedBox(height: 22),
        _SettingsDropdown<TaskCompletionSound>(
          label: '完成音频设置',
          value: completionSound,
          values: TaskCompletionSound.values,
          itemLabel: (value) => value.settingsLabel,
          onChanged: (value) {
            if (value == null) {
              return;
            }
            updateViewState(() => completionSound = value);
          },
        ),
        const SizedBox(height: 18),
        _SettingsDropdown<AppCloseBehavior>(
          label: '关闭窗口时',
          value: closeBehavior,
          values: AppCloseBehavior.values,
          itemLabel: (value) => value.settingsLabel,
          onChanged: (value) {
            if (value != null) {
              updateViewState(() => closeBehavior = value);
            }
          },
        ),
        const SizedBox(height: 18),
        _SettingsDropdown<int>(
          label: '最大并行任务数',
          value: maxConcurrentExecutions,
          values: const [
            minConcurrentExecutions,
            defaultMaxConcurrentExecutions,
            maxConcurrentExecutionsLimit,
          ],
          itemLabel: (value) =>
              value == defaultMaxConcurrentExecutions ? '$value（推荐）' : '$value',
          onChanged: (value) {
            if (value == null) {
              return;
            }
            updateViewState(() => maxConcurrentExecutions = value);
          },
        ),
        const SizedBox(height: 18),
        _SettingsDropdown<int>(
          label: '文件夹扫描层级',
          value: folderImportScanDepth,
          values: const [
            minFolderImportScanDepth,
            1,
            defaultFolderImportScanDepth,
            3,
            maxFolderImportScanDepth,
          ],
          itemLabel: (value) =>
              value == defaultFolderImportScanDepth ? '$value（默认）' : '$value',
          onChanged: (value) {
            if (value == null) {
              return;
            }
            updateViewState(() => folderImportScanDepth = value);
          },
        ),
        const SizedBox(height: 8),
        Text(
          '扫描层级越深，导入前遍历时间越长。',
          style: TextStyle(
            color: context.frameLeanColors.textSecondary,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        _SettingsCheckbox(
          label: '关闭通知角标',
          value: hideNotificationBadge,
          onChanged: (value) {
            updateViewState(() => hideNotificationBadge = value);
          },
        ),
        const SizedBox(height: 32),
        _SectionActions(
          dirty: isSectionDirty(_SettingsSection.app),
          saving: savingSection == _SettingsSection.app,
          onCancel: () => _revertSection(_SettingsSection.app),
          onSave: () => _saveSection(_SettingsSection.app),
        ),
      ],
    );
  }

  Widget buildNotificationSettingsSection() {
    return _SettingsForm(
      title: '通知设置',
      children: [
        Text(
          '通知会写入通知中心；临时通知只在当前界面短暂显示；不通知会完全抑制该事件。提示音仍由应用设置独立控制。',
          style: TextStyle(
            color: context.frameLeanColors.textSecondary,
            fontSize: 12,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),
        _NotificationPolicyTable(
          policies: notificationPolicies,
          onChanged: (event, mode) {
            updateViewState(() {
              notificationPolicies = {...notificationPolicies, event: mode};
            });
          },
        ),
        const SizedBox(height: 28),
        _SectionActions(
          dirty: isSectionDirty(_SettingsSection.notifications),
          saving: savingSection == _SettingsSection.notifications,
          onCancel: () => _revertSection(_SettingsSection.notifications),
          onSave: () => _saveSection(_SettingsSection.notifications),
        ),
      ],
    );
  }

  Widget buildShortcutSettingsSection() {
    return _SettingsForm(
      title: '快捷键',
      children: [
        Text(
          'Esc 固定用于关闭最上层界面或返回，工作台根页面不执行任何操作。输入框聚焦时会抑制普通无修饰键快捷键。',
          style: TextStyle(
            color: context.frameLeanColors.textSecondary,
            fontSize: 12,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),
        for (final action in AppShortcutAction.values) ...[
          _ShortcutBindingRow(
            action: action,
            binding:
                shortcutBindings[action] ?? defaultAppShortcutBindings[action]!,
            onRecord: () => recordShortcut(action),
          ),
          if (action != AppShortcutAction.values.last)
            const SizedBox(height: 10),
        ],
        if (shortcutConflictMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            shortcutConflictMessage!,
            style: TextStyle(
              color: context.frameLeanColors.statusFailed,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 18),
        TextButton.icon(
          onPressed: () {
            updateViewState(() {
              shortcutConflictMessage = null;
              shortcutBindings = Map.of(defaultAppShortcutBindings);
            });
          },
          icon: const Icon(Icons.restart_alt_rounded, size: 16),
          label: const Text('恢复默认快捷键'),
        ),
        const SizedBox(height: 22),
        _SectionActions(
          dirty: isSectionDirty(_SettingsSection.shortcuts),
          saving: savingSection == _SettingsSection.shortcuts,
          onCancel: () => _revertSection(_SettingsSection.shortcuts),
          onSave: () => _saveSection(_SettingsSection.shortcuts),
        ),
      ],
    );
  }

  Widget buildAboutSection() {
    final colors = context.frameLeanColors;
    final iconPath = Theme.of(context).brightness == Brightness.dark
        ? 'assets/app_icon/light.png'
        : 'assets/app_icon/dark.png';
    return _SettingsForm(
      title: '关于',
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Image.asset(
            iconPath,
            width: 62,
            height: 62,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 18),
        _AboutTextBlock(
          title: '项目简介',
          body:
              'FrameLean（帧轻）是一个本地桌面媒体压缩与格式处理工具。'
              '基于 Flutter Desktop、FFmpeg / FFprobe、Riverpod、Drift 和 SQLite 构建。'
              '它把常用的视频、图片、音频分析、压缩、格式输出配置和任务队列能力封装成图形界面，'
              '让用户不用手写 FFmpeg 命令也能处理本地媒体文件。',
        ),
        const SizedBox(height: 18),
        _AboutTextBlock(
          title: '作者想说的话',
          body:
              '非常感谢你下载并使用我的应用，作者我通过比赛接触了 Flutter 和移动端开发近 2 年，'
              '这是我的第一款独立开发的应用。在使用过程中如果遇到了什么问题或者什么功能让你感到不方便，'
              '可以通过下面的方式联系作者，作者非常需要你提出的宝贵建议。',
        ),
        const SizedBox(height: 12),
        Text(
          '当前版本：${FrameLeanBuildInfo.currentVersionLabel}',
          style: TextStyle(color: colors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 14),
        _AboutIconLinks(onOpenLink: widget.onOpenExternalLink ?? (_) async {}),
        const SizedBox(height: 30),
        _AboutActionCluster(
          label: '更新',
          children: [
            _UpdateMaintenanceButton(
              state: widget.updateState,
              manualMacosUpdate: widget.manualMacosUpdate,
              onCheckUpdate: widget.onCheckUpdate,
              onStartOrResumeDownload: widget.onStartOrResumeUpdateDownload,
              onPauseDownload: widget.onPauseUpdateDownload,
              onInstallUpdate: widget.onInstallUpdate,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _AboutActionCluster(
          label: '维护',
          children: [
            _MaintenanceButton(
              label: clearingCache ? '正在清理' : '清空应用缓存',
              icon: Icons.cleaning_services_outlined,
              onPressed: clearingCache ? null : confirmClearAppCache,
            ),
          ],
        ),
      ],
    );
  }

  Widget buildVideoSection() {
    final config = videoConfig;
    final smartPreset = config.smartPreset ?? SmartCompressionPreset.chat;

    return _SettingsForm(
      title: '视频任务默认值配置',
      children: [
        _SettingsDropdown<CompressionMode>(
          label: '默认模式选择',
          value: defaultMediaConfig.compressionMode,
          values: const [CompressionMode.preset, CompressionMode.targetSize],
          itemLabel: (value) {
            return switch (value) {
              CompressionMode.preset => '推荐方案选项',
              CompressionMode.targetSize => '自定义目标体积',
            };
          },
          onChanged: (value) {
            if (value == null) {
              return;
            }
            updateViewState(() {
              defaultMediaConfig = defaultMediaConfig.copyWith(
                compressionMode: value,
                targetSizeRatio: value == CompressionMode.targetSize
                    ? defaultTargetSizeRatio
                    : null,
                targetSizeBytes: null,
              );
            });
          },
        ),
        const SizedBox(height: 22),
        _SettingsDropdown<SmartCompressionPreset>(
          label: '默认推荐方案预设',
          value: smartPreset,
          values: SmartCompressionPreset.values,
          itemLabel: (value) => value.label,
          onChanged: (value) {
            if (value == null) {
              return;
            }
            updateVideoConfig(config.copyWith(smartPreset: value));
          },
        ),
        const SizedBox(height: 22),
        _SettingsOutputFormatField(
          label: '默认输出格式',
          keepOriginalLabel: '默认保持源文件视频格式',
          value: config.outputFormat,
          values: MediaOutputFormat.formatsFor(MediaKind.video),
          keepOriginal: config.keepOriginalOutputFormat,
          onKeepOriginalChanged: (value) {
            updateVideoConfig(config.copyWith(keepOriginalOutputFormat: value));
          },
          onChanged: (value) {
            final outputFormat = value.toVideoOutputFormat();
            final nextCodec =
                VideoOutputCompatibility.supports(
                  outputFormat,
                  config.videoCodec,
                )
                ? config.videoCodec
                : VideoOutputCompatibility.defaultCodecFor(outputFormat);
            updateVideoConfig(
              config.copyWith(
                outputFormat: value,
                keepOriginalOutputFormat: false,
                videoCodec: nextCodec,
                encoderBackend: EncoderBackend.auto,
              ),
            );
          },
        ),
        const SizedBox(height: 22),
        _TwoColumnFields(
          children: [
            _SettingsDropdown<VideoCodec>(
              label: '默认编码格式',
              value: config.videoCodec,
              values: VideoOutputCompatibility.codecsFor(
                config.outputFormat.toVideoOutputFormat(),
              ),
              itemLabel: (value) => value.label,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                updateVideoConfig(
                  config.copyWith(
                    videoCodec: value,
                    encoderBackend: EncoderBackend.auto,
                  ),
                );
              },
              enabled: !config.keepOriginalOutputFormat,
            ),
            _SettingsDropdown<ResolutionPreset>(
              label: '默认视频分辨率',
              value: config.resolutionPreset,
              values: ResolutionPreset.values,
              itemLabel: (value) => value.label,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                updateVideoConfig(config.copyWith(resolutionPreset: value));
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsCheckbox(
          label: '保留视频元数据',
          value: config.preserveMetadata,
          onChanged: (value) {
            updateVideoConfig(config.copyWith(preserveMetadata: value));
          },
        ),
        const SizedBox(height: 32),
        _SectionActions(
          dirty: isSectionDirty(_SettingsSection.video),
          saving: savingSection == _SettingsSection.video,
          onCancel: () => _revertSection(_SettingsSection.video),
          onSave: () => _saveSection(_SettingsSection.video),
        ),
      ],
    );
  }

  Widget buildImageSection() {
    final config = imageConfig;

    return _SettingsForm(
      title: '图片任务默认值配置',
      children: [
        _SettingsOutputFormatField(
          label: '默认输出格式',
          keepOriginalLabel: '默认保持源文件图片格式',
          value: config.outputFormat,
          values: MediaOutputFormat.formatsFor(MediaKind.image),
          keepOriginal: config.keepOriginalOutputFormat,
          onKeepOriginalChanged: (value) {
            updateImageConfig(config.copyWith(keepOriginalOutputFormat: value));
          },
          onChanged: (value) {
            updateImageConfig(
              config.copyWith(
                outputFormat: value,
                keepOriginalOutputFormat: false,
              ),
            );
          },
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: 360,
          child: PercentageSliderPanel(
            title: '默认图片质量',
            summaryBuilder: (ratio) => '${(ratio * 100).round()}%',
            values: imageQualityRatios,
            selectedValue: config.imageQuality.clamp(1, 100).toDouble() / 100,
            showTickLabels: false,
            onChanged: (value) {
              updateImageConfig(
                config.copyWith(imageQuality: (value * 100).round()),
              );
            },
          ),
        ),
        const SizedBox(height: 22),
        _SettingsDropdown<ImageResizePreset>(
          label: '默认图片尺寸',
          width: 285,
          value: config.resizePreset,
          values: ImageResizePreset.values,
          itemLabel: (value) => value.label,
          onChanged: (value) {
            if (value == null) {
              return;
            }
            updateImageConfig(config.copyWith(resizePreset: value));
          },
        ),
        const SizedBox(height: 16),
        _SettingsCheckbox(
          label: '保留图片元数据',
          value: config.preserveMetadata,
          onChanged: (value) {
            updateImageConfig(config.copyWith(preserveMetadata: value));
          },
        ),
        const SizedBox(height: 32),
        _SectionActions(
          dirty: isSectionDirty(_SettingsSection.image),
          saving: savingSection == _SettingsSection.image,
          onCancel: () => _revertSection(_SettingsSection.image),
          onSave: () => _saveSection(_SettingsSection.image),
        ),
      ],
    );
  }

  Widget buildAudioSection() {
    final config = audioConfig;

    return _SettingsForm(
      title: '音频任务默认值配置',
      children: [
        _SettingsOutputFormatField(
          label: '默认输出格式',
          keepOriginalLabel: '默认保持源文件音频格式',
          value: config.outputFormat,
          values: MediaOutputFormat.formatsFor(MediaKind.audio),
          keepOriginal: config.keepOriginalOutputFormat,
          onKeepOriginalChanged: (value) {
            updateAudioConfig(config.copyWith(keepOriginalOutputFormat: value));
          },
          onChanged: (value) {
            updateAudioConfig(
              config.copyWith(
                outputFormat: value,
                keepOriginalOutputFormat: false,
              ),
            );
          },
        ),
        const SizedBox(height: 22),
        _SettingsDropdown<AudioBitratePreset>(
          label: '默认码率',
          width: 285,
          value: config.bitratePreset,
          values: AudioBitratePreset.values,
          itemLabel: (value) => value.label,
          onChanged: (value) {
            if (value == null) {
              return;
            }
            updateAudioConfig(config.copyWith(bitratePreset: value));
          },
        ),
        const SizedBox(height: 22),
        _TwoColumnFields(
          children: [
            _SettingsDropdown<AudioSampleRatePreset>(
              label: '默认采样率',
              value: config.sampleRate,
              values: AudioSampleRatePreset.values,
              itemLabel: (value) => value.label,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                updateAudioConfig(config.copyWith(sampleRate: value));
              },
            ),
            _SettingsDropdown<AudioChannelsPreset>(
              label: '默认声道',
              value: config.channels,
              values: AudioChannelsPreset.values,
              itemLabel: (value) => value.label,
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                updateAudioConfig(config.copyWith(channels: value));
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SettingsCheckbox(
          label: '保留音频元数据',
          value: config.preserveMetadata,
          onChanged: (value) {
            updateAudioConfig(config.copyWith(preserveMetadata: value));
          },
        ),
        const SizedBox(height: 32),
        _SectionActions(
          dirty: isSectionDirty(_SettingsSection.audio),
          saving: savingSection == _SettingsSection.audio,
          onCancel: () => _revertSection(_SettingsSection.audio),
          onSave: () => _saveSection(_SettingsSection.audio),
        ),
      ],
    );
  }

  Widget buildOutputSection() {
    return _SettingsForm(
      title: '输出配置',
      children: [
        _FormFieldLabel('默认导出地址'),
        const SizedBox(height: 8),
        _SettingsCheckbox(
          label: '保存到源文件旁',
          value: saveOutputToSourceDirectory,
          onChanged: (value) {
            updateViewState(() => saveOutputToSourceDirectory = value);
          },
        ),
        const SizedBox(height: 8),
        _SettingsPathField(
          controller: outputDirectoryController,
          enabled: !saveOutputToSourceDirectory,
          highlighted: outputDirectoryDragging,
          hintText: widget.fallbackDefaultDirectory,
          trailingTooltip: '选择文件夹',
          onTrailingTap: pickOutputDirectory,
          onDraggingChanged: (value) {
            updateViewState(() => outputDirectoryDragging = value);
          },
          onDropped: handleOutputDirectoryDrop,
        ),
        const SizedBox(height: 22),
        _OutputFileNameTemplateField(
          controller: outputFileNameTemplateController,
          onChanged: (_) {
            updateViewState(() {});
          },
          onTemplateSelected: (template) {
            updateViewState(() {
              outputFileNameTemplateController.text = template;
              outputFileNameTemplateController.selection =
                  TextSelection.collapsed(offset: template.length);
            });
          },
        ),
        const SizedBox(height: 8),
        const _OutputTemplateVariableHelp(),
        const SizedBox(height: 32),
        _SectionActions(
          dirty: isSectionDirty(_SettingsSection.output),
          saving: savingSection == _SettingsSection.output,
          onCancel: () => _revertSection(_SettingsSection.output),
          onSave: () => _saveSection(_SettingsSection.output),
        ),
      ],
    );
  }

  Widget buildEncoderSection() {
    return _SettingsForm(
      title: '编码器配置',
      children: [
        _FormFieldLabel('FFmpeg路径'),
        const SizedBox(height: 8),
        _SettingsPathField(
          controller: ffmpegPathController,
          enabled: true,
          highlighted: ffmpegPathDragging,
          hintText: '使用内置 FFmpeg',
          trailingTooltip: '选择 FFmpeg',
          onTrailingTap: pickFfmpegPath,
          onDraggingChanged: (value) {
            updateViewState(() => ffmpegPathDragging = value);
          },
          onDropped: handleFfmpegPathDrop,
        ),
        const SizedBox(height: 18),
        _FormFieldLabel('FFprobe路径'),
        const SizedBox(height: 8),
        _SettingsPathField(
          controller: ffprobePathController,
          enabled: true,
          highlighted: ffprobePathDragging,
          hintText: '使用内置 FFprobe',
          trailingTooltip: '选择 FFprobe',
          onTrailingTap: pickFfprobePath,
          onDraggingChanged: (value) {
            updateViewState(() => ffprobePathDragging = value);
          },
          onDropped: handleFfprobePathDrop,
        ),
        const SizedBox(height: 32),
        _SectionActions(
          dirty: isSectionDirty(_SettingsSection.encoder),
          saving: savingSection == _SettingsSection.encoder,
          onCancel: () => _revertSection(_SettingsSection.encoder),
          onSave: () => _saveSection(_SettingsSection.encoder),
        ),
      ],
    );
  }

  void updateVideoConfig(VideoProcessingConfig config) {
    updateViewState(() {
      defaultMediaConfig = defaultMediaConfig.copyWith(video: config);
    });
  }

  void updateImageConfig(ImageProcessingConfig config) {
    updateViewState(() {
      defaultMediaConfig = defaultMediaConfig.copyWith(image: config);
    });
  }

  void updateAudioConfig(AudioProcessingConfig config) {
    updateViewState(() {
      defaultMediaConfig = defaultMediaConfig.copyWith(audio: config);
    });
  }
}

class _OutputFileNameTemplateField extends StatelessWidget {
  const _OutputFileNameTemplateField({
    required this.controller,
    required this.onChanged,
    required this.onTemplateSelected,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onTemplateSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return SizedBox(
      width: 360,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FormFieldLabel('默认导出文件名模板'),
          const SizedBox(height: 8),
          Container(
            height: _AppSettingsViewState._fieldHeight,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    inputFormatters: const [
                      _OutputTemplateTextInputFormatter(),
                    ],
                    maxLines: 1,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 12.flSp,
                    ),
                    decoration: InputDecoration(
                      hintText: defaultOutputFileNameTemplatePattern,
                      hintStyle: TextStyle(
                        color: colors.textTertiary,
                        fontSize: 12.flSp,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.only(left: 14, right: 8),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: '选择常用模板',
                  padding: EdgeInsets.zero,
                  offset: const Offset(0, 2),
                  color: colors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  onSelected: onTemplateSelected,
                  itemBuilder: (context) {
                    return [
                      for (final option in _outputFileNameTemplateOptions)
                        PopupMenuItem<String>(
                          value: option.template,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.label,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                option.template,
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ];
                  },
                  child: SizedBox(
                    width: _AppSettingsViewState._fieldHeight,
                    height: _AppSettingsViewState._fieldHeight,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: colors.iconMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OutputTemplateVariableHelp extends StatelessWidget {
  const _OutputTemplateVariableHelp();

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final style = TextStyle(
      color: colors.textSecondary,
      fontSize: 12,
      height: 1.45,
    );

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('文件名模板用于生成默认导出名。没有 {version} 时，重名会追加“（1）”“（2）”。', style: style),
          const SizedBox(height: 8),
          Text(
            '如果模板包含 {version}，重复导出会优先递增为 v2、v3，再继续处理重名。',
            style: style.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: 10),
          _OutputTemplateVariableHelpRow(
            token: 'source',
            description: '源文件名',
            style: style,
          ),
          _OutputTemplateVariableHelpRow(
            token: 'date',
            description: '当前日期（yyyyMMdd）',
            style: style,
          ),
          _OutputTemplateVariableHelpRow(
            token: 'version',
            description: '输出版本（v1 / v2 ...）',
            style: style,
          ),
          _OutputTemplateVariableHelpRow(
            token: 'action',
            description: '任务类型（压缩 / 转换 / 处理）',
            style: style,
          ),
          _OutputTemplateVariableHelpRow(
            token: 'codec',
            description: '编码格式（h264 / h265）',
            style: style,
          ),
          _OutputTemplateVariableHelpRow(
            token: 'encoder',
            description: '视频编码器（x264 / x265 / videotoolbox 等）',
            style: style,
          ),
        ],
      ),
    );
  }
}

class _OutputTemplateVariableHelpRow extends StatelessWidget {
  const _OutputTemplateVariableHelpRow({
    required this.token,
    required this.description,
    required this.style,
  });

  final String token;
  final String description;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: token),
          TextSpan(text: ': $description'),
        ],
      ),
      style: style,
    );
  }
}

class _OutputTemplateTextInputFormatter extends TextInputFormatter {
  const _OutputTemplateTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = normalizeOutputFileNameTemplateText(newValue.text);
    if (normalized == newValue.text) {
      return newValue;
    }

    final baseOffset = normalizeOutputFileNameTemplateText(
      newValue.text.substring(0, newValue.selection.baseOffset),
    ).length;
    final extentOffset = normalizeOutputFileNameTemplateText(
      newValue.text.substring(0, newValue.selection.extentOffset),
    ).length;

    return TextEditingValue(
      text: normalized,
      selection: TextSelection(
        baseOffset: baseOffset,
        extentOffset: extentOffset,
        affinity: newValue.selection.affinity,
        isDirectional: newValue.selection.isDirectional,
      ),
    );
  }
}

class _OutputFileNameTemplateOption {
  const _OutputFileNameTemplateOption({
    required this.label,
    required this.template,
  });

  final String label;
  final String template;
}

const _outputFileNameTemplateOptions = [
  _OutputFileNameTemplateOption(
    label: '源文件名 + 行为',
    template: '{source}-{action}',
  ),
  _OutputFileNameTemplateOption(
    label: '源文件名 + 时间 + 行为 + 版本',
    template: '{source}-{date}-{action}-{version}',
  ),
  _OutputFileNameTemplateOption(
    label: '源文件名 + 时间 + 行为',
    template: '{source}-{date}-{action}',
  ),
  _OutputFileNameTemplateOption(
    label: '源文件名 + 编码格式',
    template: '{source}-{codec}',
  ),
  _OutputFileNameTemplateOption(
    label: '源文件名 + 编码器',
    template: '{source}-{encoder}',
  ),
  _OutputFileNameTemplateOption(
    label: '源文件名 + 时间',
    template: '{source}-{date}',
  ),
  _OutputFileNameTemplateOption(label: '仅源文件名', template: '{source}'),
];
