import 'package:flutter/material.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';

class SidebarPageScaffold extends StatelessWidget {
  const SidebarPageScaffold({
    super.key,
    required this.sidebar,
    required this.content,
    this.sidebarWidth = 168.0,
  });

  final Widget sidebar;
  final Widget content;
  final double sidebarWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.surface),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            SizedBox(width: sidebarWidth, child: sidebar),
            VerticalDivider(width: 1, thickness: 1, color: colors.border),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}
