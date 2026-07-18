import 'package:flutter/material.dart';
import 'package:framelean/app/constants.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';

class SidebarPageScaffold extends StatelessWidget {
  const SidebarPageScaffold({
    super.key,
    required this.backTitle,
    /// 返回点击事件
    required this.onBackPressed,
    /// 退出时加载状态
    this.isBackLoading = false,
    this.sidebarPadding = const EdgeInsets.fromLTRB(
      16, topBarHeight, 16, 0,
    ),
    required this.sidebar,
    required this.content,
    this.sidebarWidth = 168.0,
  });

  final String backTitle;
  final VoidCallback onBackPressed;
  final bool isBackLoading;
  final EdgeInsetsGeometry sidebarPadding;
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
            SizedBox(
              width: sidebarWidth,
              child: Padding(
                padding: sidebarPadding,
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: isBackLoading ? null : onBackPressed,
                      child: SizedBox(
                        height: 26,
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Icon(
                              Icons.chevron_left_rounded,
                              color: colors.textPrimary,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                backTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 34),
                    Expanded(child: sidebar),
                  ],
                ),
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: colors.border),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}
