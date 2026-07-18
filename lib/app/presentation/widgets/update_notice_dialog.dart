import 'package:flutter/material.dart';
import 'package:framelean/app/library.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';

/// 更新通知弹窗（L2）。
///
/// 尺寸更小（380×320），信息密度更低，替代旧的全量 markdown 弹窗。
/// 按状态切换主按钮文案与可用操作；mandatory 更新隐藏「下次再说」且弹窗不可关闭。
///
/// 入口：
/// - 工作台右上角轻提示点击
/// - 开机自启自动检查发现更新（未 snooze）
/// - 设置页「检查更新」发现更新
/// - 通知中心更新通知点击（当前版本）
class UpdateNoticeDialog extends StatelessWidget {
  const UpdateNoticeDialog({
    super.key,
    required this.updateState,
    required this.manualMacosUpdate,
    required this.onStartDownload,
    required this.onPauseDownload,
    required this.onInstallUpdate,
    required this.onSnooze,
    required this.onOpenReleaseNotes,
    this.onOpenGitHub,
    this.onOpenGitee,
    this.onOpenBackup,
  });

  final AppUpdateState updateState;
  final bool manualMacosUpdate;
  final VoidCallback onStartDownload;
  final VoidCallback onPauseDownload;
  final VoidCallback onInstallUpdate;
  final VoidCallback onSnooze;
  final VoidCallback onOpenReleaseNotes;
  final VoidCallback? onOpenGitHub;
  final VoidCallback? onOpenGitee;
  final VoidCallback? onOpenBackup;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final release = updateState.release;
    final mandatory = release?.mandatory ?? false;

    return PopScope(
      canPop: !mandatory,
      child: AppDialogFrame(
        maxWidth: 380,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: SizedBox(
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NoticeHeader(
                state: updateState,
                manualMacosUpdate: manualMacosUpdate,
              ),
              const SizedBox(height: 16),
              _NoticeVersionRow(state: updateState),
              const SizedBox(height: 12),
              Expanded(child: _NoticeBody(state: updateState)),
              const SizedBox(height: 14),
              _NoticeProgressBlock(state: updateState),
              const SizedBox(height: 12),
              Divider(height: 1, thickness: 0.5, color: colors.border),
              const SizedBox(height: 12),
              _NoticeActions(
                state: updateState,
                manualMacosUpdate: manualMacosUpdate,
                mandatory: mandatory,
                onStartDownload: onStartDownload,
                onPauseDownload: onPauseDownload,
                onInstallUpdate: onInstallUpdate,
                onSnooze: onSnooze,
                onOpenReleaseNotes: onOpenReleaseNotes,
                onOpenGitHub: onOpenGitHub,
                onOpenGitee: onOpenGitee,
                onOpenBackup: onOpenBackup,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoticeHeader extends StatelessWidget {
  const _NoticeHeader({required this.state, required this.manualMacosUpdate});

  final AppUpdateState state;
  final bool manualMacosUpdate;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final status = state.status;
    final release = state.release;

    final (title, subtitle, iconColor) = switch (status) {
      AppUpdateStatus.downloading => (
        '正在下载更新',
        release != null ? 'v${release.version}' : '',
        colors.primary,
      ),
      AppUpdateStatus.paused => (
        '下载已暂停',
        release != null ? 'v${release.version}' : '',
        colors.textTertiary,
      ),
      AppUpdateStatus.downloaded => (
        manualMacosUpdate ? 'DMG 已下载' : '更新已就绪',
        release != null ? 'v${release.version} · ${release.platform}' : '',
        colors.statusRunning,
      ),
      AppUpdateStatus.installing => ('正在安装更新', '', colors.primary),
      AppUpdateStatus.failed => (
        '更新失败',
        state.errorMessage ?? '请稍后重试',
        colors.statusFailed,
      ),
      _ => (
        '发现新版本',
        release != null ? 'v${release.version}' : '',
        colors.primary,
      ),
    };

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: iconColor.withAlpha(30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            status == AppUpdateStatus.downloaded
                ? Icons.download_done_rounded
                : status == AppUpdateStatus.failed
                ? Icons.error_outline_rounded
                : Icons.system_update_outlined,
            size: 16,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: TextStyle(color: colors.textTertiary, fontSize: 11),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoticeVersionRow extends StatelessWidget {
  const _NoticeVersionRow({required this.state});

  final AppUpdateState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final release = state.release;
    if (release == null) {
      return const SizedBox.shrink();
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          'v${release.version}',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '从 v${FrameLeanBuildInfo.currentVersionLabel} 升级',
          style: TextStyle(color: colors.textTertiary, fontSize: 11),
        ),
      ],
    );
  }
}

class _NoticeBody extends StatelessWidget {
  const _NoticeBody({required this.state});

  final AppUpdateState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final release = state.release;
    if (release == null) {
      return const SizedBox.shrink();
    }

    final downloading =
        state.status == AppUpdateStatus.downloading ||
        state.status == AppUpdateStatus.paused ||
        state.status == AppUpdateStatus.installing;

    if (downloading) {
      return const SizedBox.shrink();
    }

    final summary = release.releaseNotesSummary;
    final packageInfo = release.package;
    final sizeMb = (packageInfo.sizeBytes / 1024 / 1024).toStringAsFixed(1);
    final detailText = release.hasExternalDownloadLinks
        ? '请选择下方 GitHub、Gitee 或备用地址，跳转到指定页面下载。'
        : '安装包 $sizeMb MB · ${release.platform}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary.isNotEmpty)
          Text(
            summary,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 8),
        Text(
          detailText,
          style: TextStyle(color: colors.textTertiary, fontSize: 11),
        ),
      ],
    );
  }
}

class _NoticeProgressBlock extends StatelessWidget {
  const _NoticeProgressBlock({required this.state});

  final AppUpdateState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final downloading =
        state.status == AppUpdateStatus.downloading ||
        state.status == AppUpdateStatus.paused;

    if (!downloading) {
      return const SizedBox.shrink();
    }

    final percent = state.progressPercent;
    final downloadedMb =
        (state.release?.package.sizeBytes ?? 0) * state.progress / 1024 / 1024;
    final totalMb = (state.release?.package.sizeBytes ?? 0) / 1024 / 1024;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: state.progress.clamp(0, 1),
            minHeight: 6,
            backgroundColor: colors.surfaceMuted,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              state.status == AppUpdateStatus.paused
                  ? '已暂停 $percent%'
                  : '$percent%',
              style: TextStyle(color: colors.textTertiary, fontSize: 11),
            ),
            Text(
              '${downloadedMb.toStringAsFixed(1)} / ${totalMb.toStringAsFixed(1)} MB',
              style: TextStyle(color: colors.textTertiary, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}

class _NoticeActions extends StatelessWidget {
  const _NoticeActions({
    required this.state,
    required this.manualMacosUpdate,
    required this.mandatory,
    required this.onStartDownload,
    required this.onPauseDownload,
    required this.onInstallUpdate,
    required this.onSnooze,
    required this.onOpenReleaseNotes,
    this.onOpenGitHub,
    this.onOpenGitee,
    this.onOpenBackup,
  });

  final AppUpdateState state;
  final bool manualMacosUpdate;
  final bool mandatory;
  final VoidCallback onStartDownload;
  final VoidCallback onPauseDownload;
  final VoidCallback onInstallUpdate;
  final VoidCallback onSnooze;
  final VoidCallback onOpenReleaseNotes;
  final VoidCallback? onOpenGitHub;
  final VoidCallback? onOpenGitee;
  final VoidCallback? onOpenBackup;

  bool get _hasExternalLinks => state.release?.hasExternalDownloadLinks ?? false;

  @override
  Widget build(BuildContext context) {
    final status = state.status;
    final children = switch (status) {
      AppUpdateStatus.downloading => [
        _SecondaryButton(label: '暂停下载', onPressed: onPauseDownload),
        _SecondaryButton(label: '后台下载', onPressed: onSnooze),
      ],
      AppUpdateStatus.paused => [
        _PrimaryButton(label: '继续下载', onPressed: onStartDownload),
        _SecondaryButton(label: '后台下载', onPressed: onSnooze),
      ],
      AppUpdateStatus.downloaded =>
        _downloadedActions(),
      AppUpdateStatus.installing => [
        _PrimaryButton(label: '安装中', onPressed: null),
      ],
      AppUpdateStatus.failed =>
        _failedActions(),
      _ =>
        _availableActions(),
    };

    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: children,
      ),
    );
  }

  List<Widget> _downloadedActions() {
    if (_hasExternalLinks) {
      return _externalLinkActions();
    }
    return [
      _PrimaryButton(
        label: manualMacosUpdate ? '打开 DMG' : '重启更新',
        onPressed: onInstallUpdate,
      ),
      _SecondaryButton(label: '后台隐藏', onPressed: onSnooze),
    ];
  }

  List<Widget> _failedActions() {
    if (_hasExternalLinks) {
      return _externalLinkActions();
    }
    return [
      _PrimaryButton(label: '重试', onPressed: onStartDownload),
      _SecondaryButton(label: '后台隐藏', onPressed: onSnooze),
    ];
  }

  List<Widget> _availableActions() {
    if (_hasExternalLinks) {
      return _externalLinkActions();
    }
    return [
      _PrimaryButton(label: '立即更新', onPressed: onStartDownload),
      if (!mandatory) _SecondaryButton(label: '下次再说', onPressed: onSnooze),
      _TextLinkButton(label: '查看完整日志', onPressed: onOpenReleaseNotes),
    ];
  }

  List<Widget> _externalLinkActions() {
    final buttons = <Widget>[];
    final githubUrl = state.release?.githubDownloadUrl?.trim();
    final giteeUrl = state.release?.giteeDownloadUrl?.trim();
    final backupUrl = state.release?.backupDownloadUrl?.trim();

    if (githubUrl != null && githubUrl.isNotEmpty) {
      buttons.add(
        _PrimaryLinkButton(label: '前往 GitHub', onPressed: onOpenGitHub),
      );
    }
    if (giteeUrl != null && giteeUrl.isNotEmpty) {
      buttons.add(
        _PrimaryLinkButton(label: '前往 Gitee', onPressed: onOpenGitee),
      );
    }
    if (backupUrl != null && backupUrl.isNotEmpty) {
      buttons.add(
        _PrimaryLinkButton(label: '备用地址', onPressed: onOpenBackup),
      );
    }
    if (!mandatory) {
      buttons.add(_SecondaryButton(label: '下次再说', onPressed: onSnooze));
    }
    buttons.add(
      _TextLinkButton(label: '完整日志', onPressed: onOpenReleaseNotes),
    );
    return buttons;
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return SizedBox(
      width: 92,
      height: 30,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          disabledBackgroundColor: colors.surfaceDisabled,
          disabledForegroundColor: colors.textTertiary,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}


class _PrimaryLinkButton extends StatelessWidget {
  const _PrimaryLinkButton({required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return SizedBox(
      height: 30,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.open_in_new_rounded, size: 14),
        style: FilledButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.onPrimary,
          disabledBackgroundColor: colors.surfaceDisabled,
          disabledForegroundColor: colors.textTertiary,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        label: Text(label),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return SizedBox(
      width: 76,
      height: 30,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textSecondary,
          side: BorderSide(color: colors.border),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        child: Text(label),
      ),
    );
  }
}

class _TextLinkButton extends StatelessWidget {
  const _TextLinkButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: colors.textTertiary,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        minimumSize: const Size(0, 30),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
      child: Text(label),
    );
  }
}
