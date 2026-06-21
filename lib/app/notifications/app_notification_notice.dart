import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';
import 'package:framelean/domain/enums/app_notification_level.dart';
import 'package:framelean/app/constants.dart';

class AppNotificationNotice extends StatelessWidget {
  const AppNotificationNotice({
    super.key,
    required this.title,
    required this.message,
    required this.level,
    required this.visibleListenable,
    required this.onDismissed,
    this.onTap,
    this.actionLabel,
    this.actionIcon,
    this.actionTooltip,
    this.onActionPressed,
  });

  final String title;
  final String message;
  final AppNotificationLevel level;
  final ValueListenable<bool> visibleListenable;
  final VoidCallback? onTap;
  final String? actionLabel;
  final IconData? actionIcon;
  final String? actionTooltip;
  final VoidCallback? onActionPressed;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 520;
    final horizontalMargin = compact ? 14.0 : 18.0;
    final hasDetails = message.trim().isNotEmpty;
    final expanded = hasDetails || actionLabel != null || actionIcon != null;
    final preferredMaxWidth = expanded ? 300.0 : 270.0;
    final availableWidth = screenWidth - (horizontalMargin * 2);
    final maxWidth = availableWidth < preferredMaxWidth
        ? availableWidth
        : preferredMaxWidth;
    final preferredMinWidth = expanded ? 300.0 : 260.0;
    final minWidth = compact || availableWidth < preferredMinWidth
        ? 0.0
        : preferredMinWidth;
    final top = defaultTargetPlatform == TargetPlatform.windows
        ? 14.0
        : topBarHeight;

    return Positioned(
      top: top,
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
                minWidth: minWidth,
                maxWidth: maxWidth,
              ),
              child: _NoticeCard(
                title: title,
                message: message,
                level: level,
                actionLabel: actionLabel,
                actionIcon: actionIcon,
                actionTooltip: actionTooltip,
                onActionPressed: onActionPressed,
                onDismissed: onDismissed,
                onTap: onTap,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoticeCard extends StatefulWidget {
  const _NoticeCard({
    required this.title,
    required this.message,
    required this.level,
    required this.onDismissed,
    this.onTap,
    this.actionLabel,
    this.actionIcon,
    this.actionTooltip,
    this.onActionPressed,
  });

  final String title;
  final String message;
  final AppNotificationLevel level;
  final VoidCallback? onTap;
  final String? actionLabel;
  final IconData? actionIcon;
  final String? actionTooltip;
  final VoidCallback? onActionPressed;
  final VoidCallback onDismissed;

  @override
  State<_NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends State<_NoticeCard> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final style = _NoticeStyle.resolve(context, widget.level);
    final trimmedMessage = widget.message.trim();
    final semanticsLabel = trimmedMessage.isEmpty
        ? widget.title
        : '${widget.title}：$trimmedMessage';

    return Semantics(
      container: true,
      liveRegion: true,
      label: semanticsLabel,
      child: MouseRegion(
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: Material(
          key: const ValueKey('app-notification-card'),
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface.withAlpha(244),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: colors.border),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow,
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 3, color: style.color),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(11, 12, 7, 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _NoticeIcon(style: style),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: widget.onTap,
                                  child: _NoticeContent(
                                    title: widget.title,
                                    message: trimmedMessage,
                                  ),
                                ),
                              ),
                              if (widget.onActionPressed != null &&
                                  (widget.actionLabel != null ||
                                      widget.actionIcon != null)) ...[
                                const SizedBox(width: 7),
                                _NoticeActionButton(
                                  label: widget.actionLabel,
                                  icon: widget.actionIcon,
                                  tooltip: widget.actionTooltip,
                                  color: style.color,
                                  onPressed: widget.onActionPressed!,
                                ),
                              ],
                              const SizedBox(width: 5),
                              AnimatedOpacity(
                                duration: fastTransition,
                                opacity: hovered ? 1 : 0.48,
                                child: _NoticeCloseButton(
                                  onPressed: widget.onDismissed,
                                ),
                              ),
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
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: style.backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(style.icon, size: 17, color: style.color),
    );
  }
}

class _NoticeContent extends StatelessWidget {
  const _NoticeContent({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final hasDetails = message.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 13.flSp,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (hasDetails) ...[
          const SizedBox(height: 3),
          Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12.flSp,
              height: 1.3,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }
}

class _NoticeActionButton extends StatelessWidget {
  const _NoticeActionButton({
    required this.label,
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final String? label;
  final IconData? icon;
  final String? tooltip;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final actionIcon = icon;
    if (actionIcon != null) {
      return Tooltip(
        message: tooltip ?? label ?? '操作',
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(actionIcon, size: 15),
          color: color,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 26, height: 28),
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            minimumSize: const Size(26, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            hoverColor: color.withAlpha(18),
            highlightColor: color.withAlpha(30),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
      );
    }

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: color.withAlpha(18),
        foregroundColor: color,
        minimumSize: const Size(40, 28),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: TextStyle(fontSize: 11.flSp, fontWeight: FontWeight.w700),
      ),
      child: Text(label ?? '操作'),
    );
  }
}

class _NoticeCloseButton extends StatelessWidget {
  const _NoticeCloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;

    return Tooltip(
      message: '关闭',
      child: IconButton(
        key: const ValueKey('app-notification-close-button'),
        onPressed: onPressed,
        icon: const Icon(Icons.close_rounded, size: 15),
        color: colors.iconMuted,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 26, height: 28),
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          minimumSize: const Size(26, 28),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          hoverColor: colors.surfaceMuted,
          highlightColor: colors.primarySoft,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
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

  static _NoticeStyle resolve(
    BuildContext context,
    AppNotificationLevel level,
  ) {
    final colors = context.frameLeanColors;
    switch (level) {
      case AppNotificationLevel.success:
        return _NoticeStyle(
          icon: Icons.check_rounded,
          color: colors.primary,
          backgroundColor: colors.primarySoft,
        );
      case AppNotificationLevel.warning:
        return _NoticeStyle(
          icon: Icons.warning_amber_rounded,
          color: colors.statusRunning,
          backgroundColor: colors.runningSoft,
        );
      case AppNotificationLevel.error:
        return _NoticeStyle(
          icon: Icons.error_outline_rounded,
          color: colors.statusFailed,
          backgroundColor: colors.failedSoft,
        );
      case AppNotificationLevel.info:
        return _NoticeStyle(
          icon: Icons.info_outline_rounded,
          color: colors.primary,
          backgroundColor: colors.primarySoft,
        );
    }
  }
}
