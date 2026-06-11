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

class _MaintenanceButton extends StatelessWidget {
  const _MaintenanceButton({
    required this.label,
    required this.color,
    required this.foregroundColor,
    required this.onPressed,
  });

  final String label;
  final Color color;
  final Color foregroundColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return SizedBox(
      width: 122,
      height: 28,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: foregroundColor,
          disabledBackgroundColor: colors.surfaceDisabled,
          disabledForegroundColor: colors.textTertiary,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        onPressed: onPressed,
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
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
    final foregroundColor = destructive ? colors.onDanger : colors.onPrimary;

    return AlertDialog(
      backgroundColor: colors.surface,
      title: Text(title),
      content: Text(message),
      actions: [
        if (!singleAction)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: actionColor,
            foregroundColor: foregroundColor,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}
