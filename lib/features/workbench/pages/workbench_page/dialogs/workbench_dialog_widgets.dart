import 'package:flutter/material.dart';

class WorkbenchDialogBackHeader extends StatelessWidget {
  const WorkbenchDialogBackHeader({
    super.key,
    required this.title,
    required this.onClose,
    this.trailing,
  });

  final String title;
  final VoidCallback onClose;
  final Widget? trailing;

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
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF111111),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}

class WorkbenchDialogActions extends StatelessWidget {
  const WorkbenchDialogActions({
    super.key,
    required this.onCancel,
    required this.onSave,
    this.leading,
  });

  final VoidCallback onCancel;
  final VoidCallback onSave;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: leading ?? const SizedBox.shrink(),
          ),
        ),
        WorkbenchDialogActionButton(
          label: '取消',
          backgroundColor: const Color(0xFFB8B8B8),
          onPressed: onCancel,
        ),
        const SizedBox(width: 16),
        WorkbenchDialogActionButton(
          label: '保存',
          backgroundColor: const Color(0xFF6290FF),
          onPressed: onSave,
        ),
      ],
    );
  }
}

class WorkbenchDialogActionButton extends StatelessWidget {
  const WorkbenchDialogActionButton({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.onPressed,
    this.width = 75,
  });

  final String label;
  final Color backgroundColor;
  final VoidCallback? onPressed;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
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
