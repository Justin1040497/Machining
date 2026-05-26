import 'package:flutter/material.dart';

class MediaTaskStatusStyle {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const MediaTaskStatusStyle({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });
}

class MediaTaskListAction {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const MediaTaskListAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
}
