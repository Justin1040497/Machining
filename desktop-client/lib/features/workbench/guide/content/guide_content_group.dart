import 'package:flutter/material.dart';
import 'package:framelean/features/workbench/guide/models/guide_geometry.dart';

abstract class GuideContentGroup extends StatelessWidget {
  const GuideContentGroup({super.key, required this.geometry});

  final GuideGeometry geometry;

  String get id;
}

class CompositeGuideGroup extends GuideContentGroup {
  const CompositeGuideGroup({
    super.key,
    required super.geometry,
    required this.groupId,
    required this.children,
  });

  final String groupId;
  final List<GuideContentGroup> children;

  @override
  String get id => groupId;

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: children);
  }
}

class GuideText extends StatelessWidget {
  const GuideText({
    super.key,
    required this.text,
    this.textAlign = TextAlign.left,
  });

  final String text;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Text(
      text,
      textAlign: textAlign,
      style: TextStyle(
        color: color.withValues(alpha: 0.62),
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.55,
        letterSpacing: 0.1,
      ),
    );
  }
}
