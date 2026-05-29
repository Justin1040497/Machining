import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/enums/default_output_file_name_template.dart';
import 'package:framelean/domain/enums/smart_compression_preset.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/app_settings_dialog_widgets.dart';
import 'package:framelean/features/workbench/pages/workbench_page/dialogs/workbench_dialog_widgets.dart';
import 'package:framelean/features/workbench/presentation_mappers/domain_labels.dart';
import 'package:framelean/features/workbench/widgets/form_controls/config_dropdown.dart';
import 'package:framelean/features/workbench/widgets/form_controls/path_field.dart';

typedef AppSettingsSaveCallback = Future<void> Function(AppSettings settings);
typedef AppSettingsPathPicker = Future<String?> Function();

class WorkbenchAppSettingsDialog extends StatefulWidget {
  const WorkbenchAppSettingsDialog({
    super.key,
    required this.initialSettings,
    required this.fallbackDefaultDirectory,
    required this.onClose,
    required this.onSave,
    required this.onPickOutputDirectory,
    required this.onPickFfmpegPath,
    required this.onPickFfprobePath,
  });

  final AppSettings initialSettings;
  final String fallbackDefaultDirectory;
  final VoidCallback onClose;
  final AppSettingsSaveCallback onSave;
  final AppSettingsPathPicker onPickOutputDirectory;
  final AppSettingsPathPicker onPickFfmpegPath;
  final AppSettingsPathPicker onPickFfprobePath;

  @override
  State<WorkbenchAppSettingsDialog> createState() =>
      _WorkbenchAppSettingsDialogState();
}

class _WorkbenchAppSettingsDialogState
    extends State<WorkbenchAppSettingsDialog> {
  late SmartCompressionPreset selectedPreset;
  late VideoCodec selectedCodec;
  late DefaultOutputFileNameTemplate selectedFileNameTemplate;
  late bool saveToSourceDirectory;
  late final TextEditingController outputDirectoryController;
  late final TextEditingController ffmpegPathController;
  late final TextEditingController ffprobePathController;
  bool advancedVisible = false;
  bool saving = false;
  bool outputDirectoryDragging = false;
  bool ffmpegPathDragging = false;
  bool ffprobePathDragging = false;

  @override
  void initState() {
    super.initState();
    final settings = widget.initialSettings;
    selectedPreset = settings.defaultSmartPreset;
    selectedCodec = settings.defaultOutputVideoCodec;
    selectedFileNameTemplate = settings.defaultOutputFileNameTemplate;
    saveToSourceDirectory = settings.saveOutputToSourceDirectory;
    outputDirectoryController = TextEditingController(
      text: settings.defaultOutputDirectory ?? widget.fallbackDefaultDirectory,
    );
    ffmpegPathController = TextEditingController(
      text: settings.customFfmpegPath ?? '',
    );
    ffprobePathController = TextEditingController(
      text: settings.customFfprobePath ?? '',
    );
  }

  @override
  void dispose() {
    outputDirectoryController.dispose();
    ffmpegPathController.dispose();
    ffprobePathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 410),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(25, 22, 25, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WorkbenchDialogBackHeader(
                    title: '应用设置',
                    onClose: widget.onClose,
                  ),
                  const SizedBox(height: 18),
                  ConfigDropdown<SmartCompressionPreset>(
                    label: '默认压缩配置',
                    trailingText: settingsPresetLabel(selectedPreset),
                    value: selectedPreset,
                    values: SmartCompressionPreset.values,
                    itemLabel: settingsPresetLabel,
                    height: 34,
                    showTrailingText: false,
                    labelFontSize: 12,
                    valueFontSize: 12,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedPreset = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                  const AppSettingsSectionLabel('默认导出地址'),
                  const SizedBox(height: 8),
                  AppSettingsSourceDirectoryCheckbox(
                    value: saveToSourceDirectory,
                    onChanged: (value) {
                      setState(() {
                        saveToSourceDirectory = value;
                        if (value) {
                          outputDirectoryDragging = false;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 9),
                  PathField(
                    controller: outputDirectoryController,
                    enabled: !saveToSourceDirectory,
                    hintText: '',
                    highlighted: outputDirectoryDragging,
                    trailingIcon: Icons.chevron_right_rounded,
                    height: 34,
                    fontSize: 11,
                    trailingTooltip: '选择路径',
                    onDraggingChanged: (dragging) {
                      setState(() {
                        outputDirectoryDragging = dragging;
                      });
                    },
                    onDropped: handleOutputDirectoryDrop,
                    onTrailingTap: pickOutputDirectory,
                  ),
                  const SizedBox(height: 18),
                  ConfigDropdown<DefaultOutputFileNameTemplate>(
                    label: '默认导出文件名',
                    trailingText: selectedFileNameTemplate.label,
                    value: selectedFileNameTemplate,
                    values: DefaultOutputFileNameTemplate.values,
                    itemLabel: (value) => value.label,
                    height: 34,
                    showTrailingText: false,
                    labelFontSize: 12,
                    valueFontSize: 12,
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedFileNameTemplate = value;
                        });
                      }
                    },
                  ),
                  if (advancedVisible) ...[
                    const SizedBox(height: 18),
                    const AppSettingsSectionLabel('自定义FFmpeg路径'),
                    const SizedBox(height: 8),
                    PathField(
                      controller: ffmpegPathController,
                      enabled: true,
                      highlighted: ffmpegPathDragging,
                      hintText: '为空则默认使用内置编码器',
                      trailingIcon: Icons.chevron_right_rounded,
                      height: 34,
                      fontSize: 11,
                      trailingTooltip: '选择路径',
                      onDraggingChanged: (dragging) {
                        setState(() {
                          ffmpegPathDragging = dragging;
                        });
                      },
                      onDropped: handleFfmpegPathDrop,
                      onTrailingTap: pickFfmpegPath,
                    ),
                    const SizedBox(height: 18),
                    const AppSettingsSectionLabel('自定义FFprobe路径'),
                    const SizedBox(height: 8),
                    PathField(
                      controller: ffprobePathController,
                      enabled: true,
                      highlighted: ffprobePathDragging,
                      hintText: '为空则默认使用内置分析器',
                      trailingIcon: Icons.chevron_right_rounded,
                      height: 34,
                      fontSize: 11,
                      trailingTooltip: '选择路径',
                      onDraggingChanged: (dragging) {
                        setState(() {
                          ffprobePathDragging = dragging;
                        });
                      },
                      onDropped: handleFfprobePathDrop,
                      onTrailingTap: pickFfprobePath,
                    ),
                  ],
                  SizedBox(height: advancedVisible ? 32 : 28),
                  AppSettingsActions(
                    advancedVisible: advancedVisible,
                    saving: saving,
                    onToggleAdvanced: () {
                      setState(() {
                        advancedVisible = !advancedVisible;
                      });
                    },
                    onCancel: widget.onClose,
                    onSave: save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pickOutputDirectory() async {
    final selectedPath = await widget.onPickOutputDirectory();
    if (selectedPath == null || selectedPath.trim().isEmpty) {
      return;
    }

    outputDirectoryController.text = selectedPath.trim();
  }

  Future<void> pickFfmpegPath() async {
    final selectedPath = await widget.onPickFfmpegPath();
    if (selectedPath == null || selectedPath.trim().isEmpty) {
      return;
    }

    ffmpegPathController.text = selectedPath.trim();
  }

  Future<void> pickFfprobePath() async {
    final selectedPath = await widget.onPickFfprobePath();
    if (selectedPath == null || selectedPath.trim().isEmpty) {
      return;
    }

    ffprobePathController.text = selectedPath.trim();
  }

  Future<void> handleOutputDirectoryDrop(List<DropItem> items) async {
    for (final item in items) {
      final type = await FileSystemEntity.type(item.path);
      if (type == FileSystemEntityType.directory) {
        if (!mounted) {
          return;
        }

        setState(() {
          outputDirectoryController.text = item.path;
          outputDirectoryDragging = false;
        });
        return;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      outputDirectoryDragging = false;
    });
  }

  Future<void> handleFfmpegPathDrop(List<DropItem> items) async {
    final droppedPath = await firstDroppedFilePath(items);
    if (!mounted) {
      return;
    }

    setState(() {
      if (droppedPath != null) {
        ffmpegPathController.text = droppedPath;
      }
      ffmpegPathDragging = false;
    });
  }

  Future<void> handleFfprobePathDrop(List<DropItem> items) async {
    final droppedPath = await firstDroppedFilePath(items);
    if (!mounted) {
      return;
    }

    setState(() {
      if (droppedPath != null) {
        ffprobePathController.text = droppedPath;
      }
      ffprobePathDragging = false;
    });
  }

  Future<String?> firstDroppedFilePath(List<DropItem> items) async {
    for (final item in items) {
      final droppedPath = item.path.trim();
      if (droppedPath.isEmpty || item is DropItemDirectory) {
        continue;
      }

      if (item is DropItemFile) {
        return droppedPath;
      }

      final type = await FileSystemEntity.type(droppedPath);
      if (type == FileSystemEntityType.file) {
        return droppedPath;
      }
    }

    return null;
  }

  Future<void> save() async {
    if (saving) {
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      await widget.onSave(
        widget.initialSettings.copyWith(
          defaultOutputDirectory: emptyToNull(outputDirectoryController.text),
          saveOutputToSourceDirectory: saveToSourceDirectory,
          customFfmpegPath: emptyToNull(ffmpegPathController.text),
          customFfprobePath: emptyToNull(ffprobePathController.text),
          defaultSmartPreset: selectedPreset,
          defaultOutputVideoCodec: selectedCodec,
          defaultOutputFileNameTemplate: selectedFileNameTemplate,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }
}

String settingsPresetLabel(SmartCompressionPreset value) {
  switch (value) {
    case SmartCompressionPreset.balanced:
      return '均衡方案';
    case SmartCompressionPreset.chat:
      return '微信发送';
    case SmartCompressionPreset.clear:
      return '清晰优先';
    case SmartCompressionPreset.compact:
      return '体积优先';
  }
}

String? emptyToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
