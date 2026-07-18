import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:framelean/app/library.dart';
import 'package:framelean/domain/library.dart';

class ReleaseNotesPage extends ConsumerStatefulWidget {
  const ReleaseNotesPage({super.key, this.initialVersion, this.from});

  final String? initialVersion;
  final String? from;

  @override
  ConsumerState<ReleaseNotesPage> createState() => _ReleaseNotesPageState();
}

class _ReleaseNotesPageState extends ConsumerState<ReleaseNotesPage> {
  String? selectedVersion;

  @override
  void initState() {
    super.initState();
    selectedVersion = widget.initialVersion;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final notesValue = ref.watch(appReleaseNotesProvider);
    final updateState =
        ref.watch(appUpdateProvider).asData?.value ?? AppUpdateState.initial();
    final manualMacosUpdate = ref.watch(isManualMacosUpdateProvider);

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        bottom: false,
        child: notesValue.when(
          data: (notes) => _buildContent(
            context,
            notes,
            updateState: updateState,
            manualMacosUpdate: manualMacosUpdate,
          ),
          loading: () => Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.primary,
            ),
          ),
          error: (error, _) => _ReleaseNotesEmptyState(
            message: '版本日志读取失败\n$error',
            onBack: () => _goBack(context),
            backLabel: _backLabel(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<AppReleaseNotes> notes, {
    required AppUpdateState updateState,
    required bool manualMacosUpdate,
  }) {
    if (notes.isEmpty) {
      return _ReleaseNotesEmptyState(
        message: '暂无版本日志',
        onBack: () => _goBack(context),
        backLabel: _backLabel(),
      );
    }

    final selected = _resolveSelectedNotes(notes);
    return SidebarPageScaffold(
      backTitle: _backLabel(),
      onBackPressed: () => _goBack(context),
      sidebar: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: notes.length,
        itemBuilder: (context, index) {
          final item = notes[index];
          final selectedItem = item.version == selected.version;
          return _ReleaseNotesVersionButton(
            version: item.version,
            selected: selectedItem,
            onPressed: () {
              setState(() => selectedVersion = item.version);
            },
          );
        },
      ),
      content: Padding(
        padding: const EdgeInsets.fromLTRB(44, 42, 44, 42),
        child: Stack(
          children: [
            SizedBox.expand(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: MarkdownBody(
                    data: selected.markdown,
                    styleSheet: context.frameLeanMarkdownStyleSheet,
                    selectable: true,
                    shrinkWrap: true,
                  ),
                ),
              ),
            ),
            if (_isCurrentManualMacosUpdate(
              selected,
              updateState,
              manualMacosUpdate,
            ))
              _ReleaseNotesManualMacosUpdateAction(
                state: updateState,
                onStartDownload: () {
                  return ref
                      .read(appUpdateProvider.notifier)
                      .startOrResumeDownload();
                },
                onPauseDownload: () {
                  ref.read(appUpdateProvider.notifier).pauseDownload();
                },
                onOpenDmg: () {
                  return ref
                      .read(appUpdateProvider.notifier)
                      .installDownloadedUpdate();
                },
              ),
          ],
        ),
      ),
    );
  }

  bool _isCurrentManualMacosUpdate(
    AppReleaseNotes selected,
    AppUpdateState state,
    bool manualMacosUpdate,
  ) {
    final release = state.release;
    return manualMacosUpdate &&
        release != null &&
        !release.hasExternalDownloadLinks &&
        release.version == selected.version &&
        release.buildNumber == selected.buildNumber &&
        state.isActive;
  }

  AppReleaseNotes _resolveSelectedNotes(List<AppReleaseNotes> notes) {
    final version = selectedVersion;
    if (version != null) {
      for (final item in notes) {
        if (item.version == version) {
          return item;
        }
      }
    }
    return notes.first;
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final from = widget.from;
    if (from == 'workbench') {
      context.go('/');
      return;
    }
    context.go('/settings');
  }

  String _backLabel() {
    return switch (widget.from) {
      'workbench' => '返回工作台',
      'settings' => '返回设置',
      _ => '返回',
    };
  }
}

class _ReleaseNotesManualMacosUpdateAction extends StatelessWidget {
  const _ReleaseNotesManualMacosUpdateAction({
    required this.state,
    required this.onStartDownload,
    required this.onPauseDownload,
    required this.onOpenDmg,
  });

  final AppUpdateState state;
  final Future<void> Function() onStartDownload;
  final VoidCallback onPauseDownload;
  final Future<void> Function() onOpenDmg;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    final downloading =
        state.status == AppUpdateStatus.downloading ||
        state.status == AppUpdateStatus.paused ||
        state.status == AppUpdateStatus.downloaded;
    final primaryLabel = switch (state.status) {
      AppUpdateStatus.downloading => '暂停',
      AppUpdateStatus.paused => '继续下载',
      AppUpdateStatus.downloaded => '打开 DMG',
      AppUpdateStatus.installing => '打开中',
      AppUpdateStatus.failed => '重新下载 DMG',
      _ => '下载 DMG',
    };
    final VoidCallback? primaryAction = switch (state.status) {
      AppUpdateStatus.downloading => onPauseDownload,
      AppUpdateStatus.downloaded => () {
        unawaited(onOpenDmg());
      },
      AppUpdateStatus.installing => null,
      _ => () {
        unawaited(onStartDownload());
      },
    };

    return Positioned(
      left: 0,
      right: 0,
      bottom: 20,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 760),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.status == AppUpdateStatus.downloaded
                          ? 'DMG 已保存'
                          : 'MacOS 更新将下载 DMG ',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (downloading) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: state.progress,
                          minHeight: 5,
                          backgroundColor: colors.surface,
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 112,
                height: 30,
                child: FilledButton(
                  onPressed: primaryAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    disabledBackgroundColor: colors.surfaceDisabled,
                    disabledForegroundColor: colors.textTertiary,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(primaryLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReleaseNotesVersionButton extends StatelessWidget {
  const _ReleaseNotesVersionButton({
    required this.version,
    required this.selected,
    required this.onPressed,
  });

  final String version;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          minimumSize: const Size.fromHeight(34),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          backgroundColor: selected ? colors.primarySoft : Colors.transparent,
          foregroundColor: selected ? colors.primary : colors.textSecondary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        child: Text(version),
      ),
    );
  }
}

class _ReleaseNotesEmptyState extends StatelessWidget {
  const _ReleaseNotesEmptyState({
    required this.message,
    required this.onBack,
    required this.backLabel,
  });

  final String message;
  final VoidCallback onBack;
  final String backLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.frameLeanColors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textTertiary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: onBack, child: Text(backLabel)),
        ],
      ),
    );
  }
}
