import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:framelean/app/theme/framelean_colors.dart';

export 'package:framelean/app/theme/framelean_responsive.dart';

extension FrameLeanThemeContext on BuildContext {
  FrameLeanColors get frameLeanColors {
    final theme = Theme.of(this);
    return theme.extension<FrameLeanColors>() ??
        (theme.brightness == Brightness.dark
            ? frameLeanDarkColors
            : frameLeanLightColors);
  }

  MarkdownStyleSheet get frameLeanMarkdownStyleSheet {
    final colors = frameLeanColors;
    final base = MarkdownStyleSheet.fromTheme(Theme.of(this));

    return base.copyWith(
      h1: base.h1?.copyWith(
        color: colors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      h1Padding: EdgeInsets.zero,
      h2: base.h2?.copyWith(
        color: colors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      h2Padding: const EdgeInsets.only(top: 14, bottom: 7),
      h3: base.h3?.copyWith(
        color: colors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      h3Padding: const EdgeInsets.only(top: 12, bottom: 6),
      p: base.p?.copyWith(
        color: colors.textSecondary,
        fontSize: 12,
        height: 1.45,
      ),
      pPadding: const EdgeInsets.only(bottom: 7),
      listBullet: base.listBullet?.copyWith(
        color: colors.textSecondary,
        fontSize: 12,
        height: 1.45,
      ),
      listBulletPadding: const EdgeInsets.only(top: 2),
      code: base.code?.copyWith(
        color: colors.textSecondary,
        fontSize: 12,
        backgroundColor: colors.surfaceMuted,
      ),
      codeblockDecoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.border),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      a: base.a?.copyWith(color: colors.primary),
      blockquoteDecoration: BoxDecoration(
        border: Border(left: BorderSide(color: colors.border, width: 3)),
      ),
      blockquotePadding: const EdgeInsets.only(left: 12),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
    );
  }
}
