part of '../pages/app_settings_page.dart';

extension _AppSettingsViewSectionActions on _AppSettingsViewState {
  Future<void> recordShortcut(AppShortcutAction action) async {
    final binding = await showDialog<AppShortcutBinding>(
      context: context,
      builder: (context) => _ShortcutRecorderDialog(action: action),
    );
    if (!mounted || binding == null) return;

    AppShortcutAction? conflict;
    for (final entry in shortcutBindings.entries) {
      if (entry.key != action && entry.value.signature == binding.signature) {
        conflict = entry.key;
        break;
      }
    }
    if (conflict != null) {
      updateViewState(() {
        shortcutConflictMessage =
            '“${shortcutBindingLabel(binding)}”已用于“${conflict!.settingsLabel}”。';
      });
      return;
    }

    updateViewState(() {
      shortcutConflictMessage = null;
      shortcutBindings = {...shortcutBindings, action: binding};
    });
  }

  Future<void> pickOutputDirectory() async {
    final selectedPath = await widget.onPickOutputDirectory();
    if (!mounted || selectedPath == null || selectedPath.trim().isEmpty) {
      return;
    }
    updateViewState(() => outputDirectoryController.text = selectedPath.trim());
  }

  Future<void> handleOutputDirectoryDrop(List<DropItem> items) async {
    if (items.isEmpty) {
      return;
    }
    final item = items.first;
    final type = await FileSystemEntity.type(item.path);
    if (!mounted) {
      return;
    }
    updateViewState(() {
      if (type == FileSystemEntityType.directory) {
        outputDirectoryController.text = item.path;
      }
      outputDirectoryDragging = false;
    });
  }

  Future<void> confirmClearAppCache() async {
    final previewCallback = widget.onPreviewAppCacheCleanup;
    final clearCallback = widget.onClearAppCache;
    if (previewCallback == null || clearCallback == null) {
      return;
    }

    updateViewState(() => clearingCache = true);
    try {
      final preview = await previewCallback();
      if (!mounted) {
        return;
      }

      if (preview.isEmpty) {
        await showDialog<void>(
          context: context,
          builder: (context) => const _ConfirmMaintenanceDialog(
            title: '应用缓存为空',
            message: '当前没有可以清理的应用缓存。',
            confirmLabel: '知道了',
            singleAction: true,
          ),
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _ConfirmMaintenanceDialog(
          title: '清空应用缓存',
          message:
              '将清理 ${preview.fileCount} 个文件、${preview.directoryCount} 个目录，'
              '预计释放 ${formatBytes(preview.totalBytes)}。该操作不会删除数据库、设置和导出文件。',
          confirmLabel: '清空缓存',
        ),
      );
      if (!mounted || confirmed != true) {
        return;
      }

      final result = await clearCallback();
      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (context) => _ConfirmMaintenanceDialog(
          title: '缓存已清理',
          message:
              '已删除 ${result.deletedFileCount} 个文件、'
              '${result.deletedDirectoryCount} 个目录，'
              '释放 ${formatBytes(result.releasedBytes)}。',
          confirmLabel: '完成',
          singleAction: true,
        ),
      );
    } finally {
      if (mounted) {
        updateViewState(() => clearingCache = false);
      }
    }
  }
}
