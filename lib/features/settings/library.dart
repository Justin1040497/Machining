/// features/settings 模块导出门面。
///
/// 设置功能模块。app 层经此 barrel 导入页面入口。
/// 模块内部 sections/widgets 互引用可直达文件，不对外导出。
library;

export 'pages/app_settings_page.dart';
export 'pages/release_notes_page.dart';
