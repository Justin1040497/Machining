import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:machining/domain/entities/app_settings.dart';
import 'package:machining/domain/enums/default_output_file_name_template.dart';
import 'package:machining/domain/enums/smart_compression_preset.dart';
import 'package:machining/domain/enums/video_codec.dart';
import 'package:machining/features/workbench/pages/workbench_page/config_dropdown.dart';
import 'package:machining/features/workbench/presentation_mappers/domain_labels.dart';

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
                  _SettingsHeader(onClose: widget.onClose),
                  const SizedBox(height: 18),
                  WorkbenchConfigDropdown<SmartCompressionPreset>(
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
                  const _SettingsLabel('默认导出地址'),
                  const SizedBox(height: 8),
                  _SourceDirectoryCheckbox(
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
                  DropTarget(
                    enable: !saveToSourceDirectory,
                    onDragEntered: (_) {
                      setState(() {
                        outputDirectoryDragging = true;
                      });
                    },
                    onDragExited: (_) {
                      setState(() {
                        outputDirectoryDragging = false;
                      });
                    },
                    onDragDone: (details) {
                      handleOutputDirectoryDrop(details.files);
                    },
                    child: _SettingsPathField(
                      controller: outputDirectoryController,
                      enabled: !saveToSourceDirectory,
                      highlighted: outputDirectoryDragging,
                      onPickPath: pickOutputDirectory,
                    ),
                  ),
                  const SizedBox(height: 18),
                  WorkbenchConfigDropdown<DefaultOutputFileNameTemplate>(
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
                    const _SettingsLabel('自定义FFmpeg路径'),
                    const SizedBox(height: 8),
                    DropTarget(
                      onDragEntered: (_) {
                        setState(() {
                          ffmpegPathDragging = true;
                        });
                      },
                      onDragExited: (_) {
                        setState(() {
                          ffmpegPathDragging = false;
                        });
                      },
                      onDragDone: (details) {
                        handleFfmpegPathDrop(details.files);
                      },
                      child: _SettingsPathField(
                        controller: ffmpegPathController,
                        enabled: true,
                        highlighted: ffmpegPathDragging,
                        hintText: '为空则默认使用内置编码器',
                        onPickPath: pickFfmpegPath,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _SettingsLabel('自定义FFprobe路径'),
                    const SizedBox(height: 8),
                    DropTarget(
                      onDragEntered: (_) {
                        setState(() {
                          ffprobePathDragging = true;
                        });
                      },
                      onDragExited: (_) {
                        setState(() {
                          ffprobePathDragging = false;
                        });
                      },
                      onDragDone: (details) {
                        handleFfprobePathDrop(details.files);
                      },
                      child: _SettingsPathField(
                        controller: ffprobePathController,
                        enabled: true,
                        highlighted: ffprobePathDragging,
                        hintText: '为空则默认使用内置分析器',
                        onPickPath: pickFfprobePath,
                      ),
                    ),
                  ],
                  SizedBox(height: advancedVisible ? 32 : 28),
                  _SettingsActions(
                    showAdvancedButton: !advancedVisible,
                    saving: saving,
                    onAdvanced: () {
                      setState(() {
                        advancedVisible = true;
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

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Transform.translate(
          offset: const Offset(-10, 0),
          child: SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              tooltip: '关闭',
              onPressed: onClose,
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.keyboard_arrow_left_rounded,
                color: Colors.black,
                size: 24,
              ),
            ),
          ),
        ),
        const SizedBox(width: 1),
        const Text(
          '应用设置',
          style: TextStyle(
            color: Color(0xFF111111),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SettingsLabel extends StatelessWidget {
  const _SettingsLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF111111),
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class _SourceDirectoryCheckbox extends StatelessWidget {
  const _SourceDirectoryCheckbox({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: Checkbox(
            value: value,
            onChanged: (value) {
              onChanged(value ?? false);
            },
            side: const BorderSide(color: Color(0xFFDCDCDC)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(width: 9),
        const Text(
          '保存到原文件旁',
          style: TextStyle(color: Color(0xFF9A9A9A), fontSize: 11),
        ),
      ],
    );
  }
}

class _SettingsPathField extends StatelessWidget {
  const _SettingsPathField({
    required this.controller,
    required this.enabled,
    required this.onPickPath,
    this.highlighted = false,
    this.hintText,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool highlighted;
  final String? hintText;
  final VoidCallback onPickPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: highlighted
              ? const Color(0xFF6290FF)
              : const Color(0xFFE3E3E3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              maxLines: 1,
              style: TextStyle(
                color: enabled
                    ? const Color(0xFF111111)
                    : const Color(0xFFCFCFCF),
                fontSize: 11,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.only(left: 14, right: 8),
                hintText: hintText,
                hintStyle: const TextStyle(
                  color: Color(0xFFCFCFCF),
                  fontSize: 11,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 34,
            height: 34,
            child: IconButton(
              tooltip: enabled ? '选择路径' : null,
              onPressed: enabled ? onPickPath : null,
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.chevron_right_rounded,
                color: enabled
                    ? const Color(0xFF9A9A9A)
                    : const Color(0xFFCFCFCF),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsActions extends StatelessWidget {
  const _SettingsActions({
    required this.showAdvancedButton,
    required this.saving,
    required this.onAdvanced,
    required this.onCancel,
    required this.onSave,
  });

  final bool showAdvancedButton;
  final bool saving;
  final VoidCallback onAdvanced;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showAdvancedButton)
          _SettingsActionButton(
            label: '高级设置',
            backgroundColor: const Color(0xFFFF6B00),
            onPressed: onAdvanced,
          ),
        const Spacer(),
        _SettingsActionButton(
          label: '取消',
          backgroundColor: const Color(0xFFB8B8B8),
          onPressed: saving ? null : onCancel,
        ),
        const SizedBox(width: 16),
        _SettingsActionButton(
          label: '保存',
          backgroundColor: const Color(0xFF6290FF),
          onPressed: saving ? null : onSave,
        ),
      ],
    );
  }
}

class _SettingsActionButton extends StatelessWidget {
  const _SettingsActionButton({
    required this.label,
    required this.backgroundColor,
    required this.onPressed,
  });

  final String label;
  final Color backgroundColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 75,
      height: 28,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: onPressed == null
              ? backgroundColor.withAlpha(150)
              : backgroundColor,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        child: Text(label),
      ),
    );
  }
}
