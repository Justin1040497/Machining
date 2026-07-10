/// features/workbench 模块导出门面。
///
/// 工作台功能模块。app 层经此 barrel 导入页面入口与状态管理。
/// 模块内部 layout/dialogs/widgets/configuration 互引用可直达文件，不对外导出。
library;

export 'pages/workbench_page.dart';
export 'providers/media_task_notifier.dart';
