import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:framelean/app/notifications/app_notification_host.dart';
import 'package:framelean/app/providers/app_update_provider.dart';
import 'package:framelean/app/providers/platform_provider.dart';
import 'package:framelean/app/providers/repository_provider.dart';
import 'package:framelean/app/providers/execution_provider.dart';
import 'package:framelean/app/theme/app_theme_controller.dart';
import 'package:framelean/app/theme/framelean_theme_context.dart';
import 'package:framelean/app/theme/theme_prefs_reconciler.dart';
import 'package:framelean/app/presentation/widgets/app_dialog_frame.dart';
import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/infrastructure/library.dart';
import 'package:framelean/app/theme/framelean_theme.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'package:framelean/app/app_router.dart';
import 'package:framelean/app/constants.dart';

class FrameLeanApp extends ConsumerStatefulWidget {
  const FrameLeanApp({super.key});

  @override
  ConsumerState<FrameLeanApp> createState() => _FrameLeanAppState();
}

class _FrameLeanAppState extends ConsumerState<FrameLeanApp>
    with WidgetsBindingObserver, WindowListener, TrayListener {
  bool _allowWindowDestroy = false;
  bool _handlingWindowClose = false;
  HotKey? _quitHotKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(reconcileThemeModeAfterStartup());
    unawaited(_cleanupInterruptedOutputsAfterStartup());
    if (Platform.isMacOS || Platform.isWindows) {
      windowManager.addListener(this);
      unawaited(_configureDesktopLifecycle());
    }
  }

  Future<void> _cleanupInterruptedOutputsAfterStartup() async {
    try {
      final settings = await LoadAppSettingsUseCase(
        repository: ref.read(appSettingsRepositoryProvider),
      ).call();
      await const LocalInterruptedOutputCleaner().cleanup(
        repository: ref.read(mediaTaskRepositoryProvider),
        settings: settings,
      );
    } on Object {
      // A failed cleanup must not prevent the workbench from opening.
    }
  }

  @override
  void dispose() {
    if (Platform.isMacOS || Platform.isWindows) {
      windowManager.removeListener(this);
    }
    if (Platform.isWindows) {
      trayManager.removeListener(this);
    }
    final quitHotKey = _quitHotKey;
    if (quitHotKey != null) {
      hotKeyManager.unregister(quitHotKey);
      _quitHotKey = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_reloadEnterpriseUpdateConfig());
    }
  }

  Future<void> _configureDesktopLifecycle() async {
    await windowManager.setPreventClose(true);

    // System-wide hotkey to quit gracefully, even when the tray icon fails.
    _quitHotKey = HotKey(
      key: LogicalKeyboardKey.keyQ,
      modifiers: [
        Platform.isMacOS ? HotKeyModifier.meta : HotKeyModifier.control,
        HotKeyModifier.shift,
      ],
      scope: HotKeyScope.system,
    );
    await hotKeyManager.register(
      _quitHotKey!,
      keyDownHandler: (_) => _requestQuit(),
    );

    if (!Platform.isWindows) return;
    trayManager.addListener(this);
    try {
      await trayManager.setIcon('assets/app_icon/tray_icon.png');
      await trayManager.setToolTip('FrameLean');
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(label: '显示 FrameLean', onClick: (_) => _showWindow()),
            MenuItem.separator(),
            MenuItem(label: '退出 FrameLean', onClick: (_) => _requestQuit()),
          ],
        ),
      );
      debugPrint('[tray] setup success');
    } on Object catch (e, st) {
      debugPrint('[tray] setup failed: $e\n$st');
    }
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onWindowClose() {
    unawaited(_handleWindowClose());
  }

  @override
  void onWindowFocus() {
    unawaited(_reloadEnterpriseUpdateConfig());
  }

  Future<void> _reloadEnterpriseUpdateConfig() async {
    try {
      await ref.read(enterpriseUpdateConfigCacheProvider).reload();
      if (Platform.isMacOS) {
        await ref
            .read(appUpdateProvider.notifier)
            .refreshPlatformUpdatePolicy();
      }
    } on Object {
      // Update policy reload must not interrupt foreground work.
    }
  }

  Future<void> _handleWindowClose() async {
    if (_allowWindowDestroy || _handlingWindowClose) return;
    _handlingWindowClose = true;
    try {
      final settings = await LoadAppSettingsUseCase(
        repository: ref.read(appSettingsRepositoryProvider),
      ).call();
      if (settings.closeBehavior == AppCloseBehavior.background) {
        await windowManager.hide();
        return;
      }
      await _requestQuit();
    } finally {
      _handlingWindowClose = false;
    }
  }

  Future<void> _requestQuit() async {
    final tasks = await ref.read(mediaTaskRepositoryProvider).loadAllTasks();
    final hasRunningTasks = tasks.any(
      (task) =>
          task.status == TaskStatus.running || task.status == TaskStatus.paused,
    );
    if (hasRunningTasks) {
      await _showWindow();
      final context = rootNavigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          final colors = context.frameLeanColors;
          return AppDialogFrame(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppDialogTitle('退出 FrameLean？'),
                const SizedBox(height: 14),
                Text(
                  '仍有运行中或已暂停的任务。退出会终止任务并清理未发布的临时输出。',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12.flSp,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppDialogActionButton(
                      label: '取消',
                      backgroundColor: colors.statusCancelled,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    const SizedBox(width: 10),
                    AppDialogActionButton(
                      label: '退出',
                      backgroundColor: colors.statusFailed,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
      if (confirmed != true) return;
    }

    await ref.read(ffmpegTaskQueueRunnerProvider).cancelAllExecutions();
    if (Platform.isWindows) await trayManager.destroy();
    _allowWindowDestroy = true;
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(_showWindow());
  }

  Future<void> reconcileThemeModeAfterStartup() async {
    final startupThemeMode = ref.read(appThemeModeProvider);
    try {
      await reconcileThemePrefsCache(
        currentThemeMode: startupThemeMode,
        loadSettings: () {
          return LoadAppSettingsUseCase(
            repository: ref.read(appSettingsRepositoryProvider),
          ).call();
        },
        setThemeMode: (mode) {
          if (mounted && ref.read(appThemeModeProvider) == startupThemeMode) {
            ref.read(appThemeModeProvider.notifier).setThemeMode(mode);
          }
        },
        writeCache: (mode) async {
          if (mounted && ref.read(appThemeModeProvider) == mode) {
            await ref.read(themePreferencesCacheProvider).write(mode);
          }
        },
      );
    } on Object {
      // 主题缓存对齐失败不影响应用启动；下次切换主题会重写缓存。
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(
      appThemeModeProvider.select((mode) => mode.materialThemeMode),
    );

    return ScreenUtilInit(
      designSize: frameLeanScreenDesignSize,
      minTextAdapt: true,
      splitScreenMode: true,
      fontSizeResolver: frameLeanFontSizeResolver,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'FrameLean',
          debugShowCheckedModeBanner: false,
          routerConfig: appRouter,
          theme: frameLeanLightTheme(),
          darkTheme: frameLeanDarkTheme(),
          themeMode: themeMode,
          themeAnimationDuration: themeTransition,
          themeAnimationCurve: Curves.easeIn,
          builder: (context, child) {
            return AppNotificationHost(child: child ?? const SizedBox.shrink());
          },
        );
      },
    );
  }
}
