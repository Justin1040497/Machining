part of '../pages/app_settings_page.dart';

extension _AppSettingsViewSectionActions on _AppSettingsViewState {
  Future<void> pickOutputDirectory() async {
    final selectedPath = await widget.onPickOutputDirectory();
    if (!mounted || selectedPath == null || selectedPath.trim().isEmpty) {
      return;
    }
    updateViewState(() => outputDirectoryController.text = selectedPath.trim());
  }

  Future<void> pickFfmpegPath() async {
    final selectedPath = await widget.onPickFfmpegPath();
    if (!mounted || selectedPath == null || selectedPath.trim().isEmpty) {
      return;
    }
    updateViewState(() => ffmpegPathController.text = selectedPath.trim());
  }

  Future<void> pickFfprobePath() async {
    final selectedPath = await widget.onPickFfprobePath();
    if (!mounted || selectedPath == null || selectedPath.trim().isEmpty) {
      return;
    }
    updateViewState(() => ffprobePathController.text = selectedPath.trim());
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

  Future<void> handleFfmpegPathDrop(List<DropItem> items) async {
    final droppedPath = await firstDroppedFilePath(items);
    if (!mounted) {
      return;
    }
    updateViewState(() {
      if (droppedPath != null) {
        ffmpegPathController.text = droppedPath;
      }
      ffmpegPathDragging = false;
    });
  }

  Future<void> handleFfprobePathDrop(List<DropItem> items) async {
    final droppedPath = await firstDroppedFilePath(items);
    if (!mounted) {
      return;
    }
    updateViewState(() {
      if (droppedPath != null) {
        ffprobePathController.text = droppedPath;
      }
      ffprobePathDragging = false;
    });
  }

  Future<String?> firstDroppedFilePath(List<DropItem> items) async {
    if (items.isEmpty) {
      return null;
    }
    final droppedPath = items.first.path.trim();
    if (droppedPath.isEmpty) {
      return null;
    }
    final type = await FileSystemEntity.type(droppedPath);
    if (type == FileSystemEntityType.file) {
      return droppedPath;
    }
    return null;
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

  Future<void> confirmUninstallApp() async {
    final availabilityCallback = widget.onLoadAppUninstallAvailability;
    final launchCallback = widget.onLaunchCleanUninstaller;
    if (availabilityCallback == null || launchCallback == null) {
      return;
    }

    updateViewState(() => uninstalling = true);
    try {
      final availability = await availabilityCallback();
      if (!mounted) {
        return;
      }

      if (!availability.available) {
        await showDialog<void>(
          context: context,
          builder: (context) => _ConfirmMaintenanceDialog(
            title: '无法卸载',
            message: availability.unavailableReason ?? '当前运行方式未找到安装器卸载信息。',
            confirmLabel: '知道了',
            singleAction: true,
          ),
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => const _ConfirmMaintenanceDialog(
          title: '卸载 FrameLean',
          message:
              '确认后应用会关闭，并启动清理卸载脚本。脚本会删除应用程序、设置、数据库、缓存和注册表记录，'
              '不会扫描或删除你导出的媒体文件。',
          confirmLabel: '卸载应用',
          destructive: true,
        ),
      );
      if (!mounted || confirmed != true) {
        return;
      }

      await launchCallback();
    } finally {
      if (mounted) {
        updateViewState(() => uninstalling = false);
      }
    }
  }
}
