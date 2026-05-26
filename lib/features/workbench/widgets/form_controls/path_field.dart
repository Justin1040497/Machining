import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

class PathField extends StatelessWidget {
  const PathField({
    super.key,
    required this.controller,
    required this.enabled,
    required this.hintText,
    this.highlighted = false,
    this.trailingIcon,
    this.height = 40,
    this.fontSize = 12,
    this.hintFontSize,
    this.trailingTooltip = '选择文件夹',
    this.onChanged,
    this.onDraggingChanged,
    this.onDropped,
    this.onTrailingTap,
  });

  final TextEditingController controller;
  final bool enabled;
  final String hintText;
  final bool highlighted;
  final IconData? trailingIcon;
  final double height;
  final double fontSize;
  final double? hintFontSize;
  final String trailingTooltip;
  final ValueChanged<String>? onChanged;
  final ValueChanged<bool>? onDraggingChanged;
  final ValueChanged<List<DropItem>>? onDropped;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      enable: enabled && onDropped != null,
      onDragEntered: (_) => onDraggingChanged?.call(true),
      onDragExited: (_) => onDraggingChanged?.call(false),
      onDragDone: (details) => onDropped?.call(details.files),
      child: Container(
        height: height,
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
                  fontSize: fontSize,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(
                    color: const Color(0xFFCFCFCF),
                    fontSize: hintFontSize ?? fontSize,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.only(left: 14, right: 8),
                ),
              ),
            ),
            if (trailingIcon != null)
              SizedBox(
                width: height,
                height: height,
                child: IconButton(
                  tooltip: enabled ? trailingTooltip : null,
                  onPressed: enabled ? onTrailingTap : null,
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    trailingIcon,
                    color: enabled
                        ? const Color(0xFF9A9A9A)
                        : const Color(0xFFCFCFCF),
                    size: 20,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
