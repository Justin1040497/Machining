import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:framelean/features/workbench/pages/workbench_page/configuration/workbench_constants.dart';

class WorkbenchNotice extends StatelessWidget {
  const WorkbenchNotice({
    super.key,
    required this.message,
    required this.visibleListenable,
    required this.onDismissed,
    this.actionLabel,
    this.onActionPressed,
  });

  final String message;
  final ValueListenable<bool> visibleListenable;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 520;
    final horizontalMargin = compact ? 18.0 : 22.0;

    return Positioned(
      top: WorkbenchConstants.appTopBarHeight + 16,
      left: compact ? horizontalMargin : null,
      right: horizontalMargin,
      child: SafeArea(
        child: Align(
          alignment: Alignment.topRight,
          child: ValueListenableBuilder<bool>(
            valueListenable: visibleListenable,
            builder: (context, visible, child) {
              return child!
                  .animate(target: visible ? 1 : 0)
                  .fade(duration: 150.ms, curve: Curves.easeOutCubic)
                  .moveX(
                    begin: 76,
                    end: 0,
                    duration: 220.ms,
                    curve: Curves.easeOutCubic,
                  );
            },
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: compact ? double.infinity : 390,
                minWidth: compact ? 0 : 320,
              ),
              child: _NoticeCard(
                message: message,
                actionLabel: actionLabel,
                onActionPressed: onActionPressed,
                onDismissed: onDismissed,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.message,
    required this.onDismissed,
    this.actionLabel,
    this.onActionPressed,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final style = _NoticeStyle.resolve(message);

    return Semantics(
      container: true,
      liveRegion: true,
      label: message,
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(242),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE0E6F0)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x18000000),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: IntrinsicHeight(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 4, color: style.color),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 11, 9, 11),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _NoticeIcon(style: style),
                            const SizedBox(width: 10),
                            Expanded(child: _NoticeMessage(message: message)),
                            if (actionLabel != null &&
                                onActionPressed != null) ...[
                              const SizedBox(width: 8),
                              _NoticeActionButton(
                                label: actionLabel!,
                                color: style.color,
                                onPressed: onActionPressed!,
                              ),
                            ],
                            const SizedBox(width: 2),
                            _NoticeCloseButton(onPressed: onDismissed),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoticeIcon extends StatelessWidget {
  const _NoticeIcon({required this.style});

  final _NoticeStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(style.icon, size: 15, color: style.color),
    );
  }
}

class _NoticeMessage extends StatelessWidget {
  const _NoticeMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        message,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xFF1D2430),
          fontSize: 13,
          height: 1.35,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _NoticeActionButton extends StatelessWidget {
  const _NoticeActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: color.withAlpha(20),
          foregroundColor: color,
          minimumSize: const Size(44, 28),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}

class _NoticeCloseButton extends StatelessWidget {
  const _NoticeCloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '关闭',
      child: IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.close_rounded, size: 16),
        color: const Color(0xFF8A9099),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 28, height: 28),
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          hoverColor: const Color(0xFFF2F4F8),
          highlightColor: const Color(0xFFE9EEF8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }
}

class _NoticeStyle {
  const _NoticeStyle({
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  final IconData icon;
  final Color color;
  final Color backgroundColor;

  static _NoticeStyle resolve(String message) {
    final normalized = message.toLowerCase();
    if (_hasAny(normalized, const [
      'error',
      'exception',
      'failed',
      '失败',
      '错误',
      '不可用',
      '不能为空',
      '打开失败',
    ])) {
      return const _NoticeStyle(
        icon: Icons.error_outline_rounded,
        color: Color(0xFFE15B4F),
        backgroundColor: Color(0xFFFFECEA),
      );
    }

    if (_hasAny(normalized, const [
      'success',
      '完成',
      '成功',
      '已保存',
      '已重新链接',
      '导入成功',
    ])) {
      return const _NoticeStyle(
        icon: Icons.check_rounded,
        color: Color(0xFF2F9E62),
        backgroundColor: Color(0xFFE8F7EE),
      );
    }

    return const _NoticeStyle(
      icon: Icons.info_outline_rounded,
      color: Color(0xFF6290FF),
      backgroundColor: Color(0xFFEFF4FF),
    );
  }

  static bool _hasAny(String message, List<String> tokens) {
    for (final token in tokens) {
      if (message.contains(token)) {
        return true;
      }
    }

    return false;
  }
}
