import 'package:flutter/material.dart';
import 'package:framelean/app/theme/framelean_colors.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';

class SimpleMarkdownView extends StatelessWidget {
  const SimpleMarkdownView({super.key, required this.markdown});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final lines = markdown.trim().isEmpty
        ? const ['暂无版本日志']
        : markdown.trim().split('\n');

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final line in lines) _buildLine(context, colors, line)],
      ),
    );
  }

  Widget _buildLine(
    BuildContext context,
    FrameLeanColors colors,
    String rawLine,
  ) {
    final line = rawLine.trimRight();
    if (line.trim().isEmpty) {
      return const SizedBox(height: 10);
    }

    if (line.startsWith('### ')) {
      return _MarkdownText(
        line.substring(4),
        color: colors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        top: 12,
        bottom: 6,
      );
    }

    if (line.startsWith('## ')) {
      return _MarkdownText(
        line.substring(3),
        color: colors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        top: 14,
        bottom: 7,
      );
    }

    if (line.startsWith('# ')) {
      return _MarkdownText(
        line.substring(2),
        color: colors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        bottom: 10,
      );
    }

    if (line.trimLeft().startsWith('- ') || line.trimLeft().startsWith('* ')) {
      final content = line.trimLeft().substring(2);
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _stripInlineMarkdown(content),
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _MarkdownText(
      _stripInlineMarkdown(line),
      color: colors.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w400,
      bottom: 7,
    );
  }
}

class _MarkdownText extends StatelessWidget {
  const _MarkdownText(
    this.text, {
    required this.color,
    required this.fontSize,
    required this.fontWeight,
    this.top = 0,
    this.bottom = 0,
  });

  final String text;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: bottom),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: 1.45,
        ),
      ),
    );
  }
}

String _stripInlineMarkdown(String value) {
  return value
      .replaceAllMapped(RegExp(r'\*\*(.*?)\*\*'), (match) => match.group(1)!)
      .replaceAllMapped(RegExp(r'`([^`]+)`'), (match) => match.group(1)!)
      .replaceAllMapped(
        RegExp(r'\[(.*?)\]\((.*?)\)'),
        (match) => match.group(1)!,
      );
}
