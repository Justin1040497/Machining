/// app 层导出门面。
///
/// app 层是 composition root，承担启动、路由、依赖装配、跨功能共享展示。
/// 跨层调用必须经此 barrel 导入，禁止直达具体文件。
/// 同层内部互引用可直达文件（属于内部实现细节）。
///
/// 不导出的内部实现（9 个）：
/// - app_router.dart（路由配置，仅 app.dart 内部用）
/// - notifications/{app_notification_host,app_notification_notice}.dart
///   （通知宿主实现，仅 app 内部用）
/// - providers/ffmpeg_planning_provider.dart（仅 execution_provider 内部组合）
/// - theme/{framelean_colors,framelean_responsive,framelean_theme,theme_prefs_reconciler}.dart
///   （主题辅助，仅 app 内部用）
/// - presentation/widgets/reorderable/src/framelean_reorderable_list_core.dart
///   （reorderable 内部实现）
library;

// 根 Widget
export 'app.dart';

// 常量
export 'constants.dart';

// presentation - 共享展示
export 'presentation/domain_labels.dart';
export 'presentation/widgets/app_dialog_frame.dart';
export 'presentation/widgets/confirm_dialog.dart';
export 'presentation/widgets/notification_center_panel.dart';
export 'presentation/widgets/percentage_slider_panel.dart';
export 'presentation/widgets/sidebar_page_scaffold.dart';
export 'presentation/widgets/update_restart_warning_dialog.dart';
export 'presentation/widgets/form_controls/config_checkbox.dart';
export 'presentation/widgets/form_controls/config_dropdown.dart';
export 'presentation/widgets/form_controls/path_field.dart';
export 'presentation/widgets/reorderable/framelean_reorderable_list_view.dart';

// providers（Riverpod 装配）
export 'providers/app_maintenance_provider.dart';
export 'providers/app_notification_provider.dart';
export 'providers/app_settings_provider.dart';
export 'providers/app_settings_save_provider.dart';
export 'providers/app_update_provider.dart';
export 'providers/database_provider.dart';
export 'providers/execution_provider.dart';
export 'providers/input_runtime_provider.dart';
export 'providers/platform_provider.dart';
export 'providers/repository_provider.dart';

// shortcuts
export 'shortcuts/app_hotkey_adapter.dart';
export 'shortcuts/app_shortcut_resolver.dart';

// theme
export 'theme/app_theme_controller.dart';
export 'theme/framelean_theme_context.dart';
