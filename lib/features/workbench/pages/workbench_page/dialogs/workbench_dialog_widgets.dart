import 'package:flutter/material.dart';

class WorkbenchDialogFrame extends StatelessWidget {
  const WorkbenchDialogFrame({
    super.key,
    required this.child,
    this.maxWidth = 410,
    this.padding = const EdgeInsets.fromLTRB(24, 22, 24, 21),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class WorkbenchDialogTitle extends StatelessWidget {
  const WorkbenchDialogTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF111111),
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class WorkbenchDialogBodyText extends StatelessWidget {
  const WorkbenchDialogBodyText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF555555),
        fontSize: 13,
        height: 1.55,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

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
