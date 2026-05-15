import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

class WorkbenchExportPathPanel extends StatelessWidget {
  const WorkbenchExportPathPanel({
    super.key,
    required this.saveToSourceDirectory,
    required this.exportDirectoryDragging,
    required this.exportDirectoryController,
    required this.outputFileNameController,
    required this.defaultExportPath,
    required this.onSaveToSourceDirectoryChanged,
    required this.onExportDirectoryDraggingChanged,
    required this.onExportDirectoryDropped,
    required this.onPickExportDirectory,
    required this.onOutputDirectoryChanged,
    required this.onOutputFileNameChanged,
  });

  final bool saveToSourceDirectory;
  final bool exportDirectoryDragging;
  final TextEditingController exportDirectoryController;
  final TextEditingController outputFileNameController;
  final String defaultExportPath;
  final ValueChanged<bool> onSaveToSourceDirectoryChanged;
  final ValueChanged<bool> onExportDirectoryDraggingChanged;
  final ValueChanged<List<DropItem>> onExportDirectoryDropped;
  final VoidCallback onPickExportDirectory;
  final ValueChanged<String> onOutputDirectoryChanged;
  final ValueChanged<String> onOutputFileNameChanged;

  @override
  Widget build(BuildContext context) {
    final statusText = saveToSourceDirectory ? '当前是原文件旁' : '当前是自定义地址';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '导出地址',
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                statusText,
                style: const TextStyle(color: Color(0xFF9A9A9A), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: Checkbox(
                  value: saveToSourceDirectory,
                  onChanged: (value) {
                    onSaveToSourceDirectoryChanged(value ?? false);
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
          ),
          const SizedBox(height: 12),
          _ExportDirectoryField(
            enabled: !saveToSourceDirectory,
            controller: exportDirectoryController,
            defaultExportPath: defaultExportPath,
            highlighted: exportDirectoryDragging,
            onDraggingChanged: onExportDirectoryDraggingChanged,
            onDropped: onExportDirectoryDropped,
            onChanged: onOutputDirectoryChanged,
            onPickDirectory: onPickExportDirectory,
          ),
          const SizedBox(height: 12),
          _ExportTextField(
            controller: outputFileNameController,
            enabled: true,
            hintText: '输出文件名（如果为空，系统会自己生成）',
            onChanged: onOutputFileNameChanged,
          ),
        ],
      ),
    );
  }
}

class _ExportDirectoryField extends StatelessWidget {
  const _ExportDirectoryField({
    required this.enabled,
    required this.controller,
    required this.defaultExportPath,
    required this.highlighted,
    required this.onDraggingChanged,
    required this.onDropped,
    required this.onChanged,
    required this.onPickDirectory,
  });

  final bool enabled;
  final TextEditingController controller;
  final String defaultExportPath;
  final bool highlighted;
  final ValueChanged<bool> onDraggingChanged;
  final ValueChanged<List<DropItem>> onDropped;
  final ValueChanged<String> onChanged;
  final VoidCallback onPickDirectory;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      enable: enabled,
      onDragEntered: (_) => onDraggingChanged(true),
      onDragExited: (_) => onDraggingChanged(false),
      onDragDone: (details) => onDropped(details.files),
      child: _ExportTextField(
        controller: controller,
        enabled: enabled,
        hintText: defaultExportPath,
        trailingIcon: Icons.chevron_right_rounded,
        highlighted: highlighted,
        onChanged: onChanged,
        onTrailingTap: enabled ? onPickDirectory : null,
      ),
    );
  }
}

class _ExportTextField extends StatelessWidget {
  const _ExportTextField({
    required this.controller,
    required this.enabled,
    required this.hintText,
    this.trailingIcon,
    this.highlighted = false,
    this.onChanged,
    this.onTrailingTap,
  });

  final TextEditingController controller;
  final bool enabled;
  final String hintText;
  final IconData? trailingIcon;
  final bool highlighted;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
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
              onChanged: onChanged,
              maxLines: 1,
              style: TextStyle(
                color: enabled
                    ? const Color(0xFF111111)
                    : const Color(0xFFCFCFCF),
                fontSize: 12,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(color: Color(0xFFCFCFCF)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.only(left: 14, right: 8),
              ),
            ),
          ),
          if (trailingIcon != null)
            IconButton(
              tooltip: enabled ? '选择文件夹' : null,
              onPressed: onTrailingTap,
              padding: EdgeInsets.zero,
              icon: Icon(
                trailingIcon,
                color: enabled
                    ? const Color(0xFF9A9A9A)
                    : const Color(0xFFCFCFCF),
                size: 20,
              ),
            ),
        ],
      ),
    );
  }
}
