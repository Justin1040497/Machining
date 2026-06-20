part of '../pages/app_settings_page.dart';

class _AboutTextBlock extends StatelessWidget {
  const _AboutTextBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 11,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _AboutIconLinks extends StatelessWidget {
  const _AboutIconLinks({required this.onOpenLink});

  final AppSettingsExternalLinkCallback onOpenLink;

  static const _links = [
    _AboutIconLink(
      label: 'Gitee',
      assetPath: 'assets/icons/gitee.png',
      url: _frameLeanGiteeUrl,
    ),
    _AboutIconLink(
      label: 'GitHub',
      assetPath: 'assets/icons/github-black.png',
      url: _frameLeanGitHubUrl,
    ),
    _AboutIconLink(
      label: 'Gmail',
      assetPath: 'assets/icons/gmail.png',
      url: _frameLeanGmailUrl,
    ),
    _AboutIconLink(
      label: '掘金',
      assetPath: 'assets/icons/juejin.png',
      url: _frameLeanJuejinUrl,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final githubAsset = isDark
        ? 'assets/icons/github-while.png'
        : 'assets/icons/github-black.png';

    return Row(
      children: [
        for (final link in _links) ...[
          _AboutIconButton(
            label: link.label,
            assetPath: link.label == 'GitHub' ? githubAsset : link.assetPath,
            onTap: () {
              unawaited(onOpenLink(link.url));
            },
          ),
          if (link != _links.last) const SizedBox(width: 17),
        ],
      ],
    );
  }
}

class _AboutIconLink {
  const _AboutIconLink({
    required this.label,
    required this.assetPath,
    required this.url,
  });

  final String label;
  final String assetPath;
  final String url;
}

class _AboutIconButton extends StatelessWidget {
  const _AboutIconButton({
    required this.label,
    required this.assetPath,
    required this.onTap,
  });

  final String label;
  final String assetPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Image.asset(assetPath, width: 20, height: 20),
          ),
        ),
      ),
    );
  }
}

class _AboutActionCluster extends StatelessWidget {
  const _AboutActionCluster({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colors.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 10, children: children),
      ],
    );
  }
}

class _MaintenanceButton extends StatelessWidget {
  const _MaintenanceButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final foregroundColor = destructive
        ? colors.statusFailed
        : colors.textPrimary;
    final borderColor = destructive
        ? colors.statusFailed.withAlpha(150)
        : colors.border;

    return SizedBox(
      width: 134,
      height: 32,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundColor,
          disabledForegroundColor: colors.textTertiary,
          side: BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(horizontal: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _UpdateMaintenanceButton extends StatelessWidget {
  const _UpdateMaintenanceButton({
    required this.state,
    required this.onCheckUpdate,
    required this.onStartOrResumeDownload,
    required this.onPauseDownload,
    required this.onInstallUpdate,
  });

  final AppUpdateState state;
  final Future<void> Function()? onCheckUpdate;
  final Future<void> Function()? onStartOrResumeDownload;
  final VoidCallback? onPauseDownload;
  final Future<void> Function()? onInstallUpdate;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final label = _labelForState(state);
    final onPressed = _actionForState();
    final showProgress =
        state.status == AppUpdateStatus.downloading ||
        state.status == AppUpdateStatus.paused ||
        state.status == AppUpdateStatus.downloaded;

    return SizedBox(
      width: 134,
      height: 32,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          disabledBackgroundColor: colors.surfaceDisabled,
          disabledForegroundColor: colors.textTertiary,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        onPressed: onPressed,
        child: showProgress
            ? SizedBox.expand(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: state.progress.clamp(0, 1),
                          child: ColoredBox(
                            color: colors.primarySoft.withAlpha(120),
                          ),
                        ),
                      ),
                      _UpdateButtonContent(label: label),
                    ],
                  ),
                ),
              )
            : _UpdateButtonContent(label: label),
      ),
    );
  }

  String _labelForState(AppUpdateState state) {
    return switch (state.status) {
      AppUpdateStatus.checking => '检查中',
      AppUpdateStatus.available => '现在更新',
      AppUpdateStatus.downloading => '${state.progressPercent}%',
      AppUpdateStatus.paused => '继续 ${state.progressPercent}%',
      AppUpdateStatus.downloaded => '重启更新',
      AppUpdateStatus.installing => '安装中',
      AppUpdateStatus.failed => state.hasUpdate ? '重试更新' : '检查更新',
      _ => '检查更新',
    };
  }

  VoidCallback? _actionForState() {
    return switch (state.status) {
      AppUpdateStatus.checking || AppUpdateStatus.installing => null,
      AppUpdateStatus.available || AppUpdateStatus.paused =>
        onStartOrResumeDownload == null
            ? null
            : () {
                unawaited(onStartOrResumeDownload!());
              },
      AppUpdateStatus.failed =>
        state.hasUpdate
            ? onStartOrResumeDownload == null
                  ? null
                  : () {
                      unawaited(onStartOrResumeDownload!());
                    }
            : onCheckUpdate == null
            ? null
            : () {
                unawaited(onCheckUpdate!());
              },
      AppUpdateStatus.downloading => onPauseDownload,
      AppUpdateStatus.downloaded =>
        onInstallUpdate == null
            ? null
            : () {
                unawaited(onInstallUpdate!());
              },
      _ =>
        onCheckUpdate == null
            ? null
            : () {
                unawaited(onCheckUpdate!());
              },
    };
  }
}

class _UpdateButtonContent extends StatelessWidget {
  const _UpdateButtonContent({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.system_update_alt_rounded, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _ConfirmMaintenanceDialog extends StatelessWidget {
  const _ConfirmMaintenanceDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.destructive = false,
    this.singleAction = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;
  final bool singleAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final actionColor = destructive ? colors.statusFailed : colors.primary;

    return AppDialogFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppDialogTitle(title),
          const SizedBox(height: 14),
          Text(
            message,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!singleAction) ...[
                AppDialogActionButton(
                  label: '取消',
                  backgroundColor: colors.statusCancelled,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                const SizedBox(width: 10),
              ],
              AppDialogActionButton(
                label: confirmLabel,
                backgroundColor: actionColor,
                onPressed: () => Navigator.of(context).pop(true),
                width: confirmLabel.length > 3 ? 86 : 75,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
