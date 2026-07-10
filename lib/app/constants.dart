export 'package:framelean/application/constants.dart';
export 'package:framelean/domain/constants.dart';

// ---------------------------------------------------------------------------
// 路由
// ---------------------------------------------------------------------------

/// 首页（工作台）
const String homeRoute = '/';

/// 设置页
const String settingsRoute = '/settings';

/// 更新日志页
const String releaseNotesRoute = '/settings/release-notes';

// ---------------------------------------------------------------------------
// 临时目录
// ---------------------------------------------------------------------------

/// 缩略图缓存子目录
const String thumbnailsSubDir = 'framelean/thumbnails';

// ---------------------------------------------------------------------------
// 动画时长
// ---------------------------------------------------------------------------

/// 快速状态过渡（通知出现/消失）
const Duration fastTransition = Duration(milliseconds: 120);

/// 悬停 / 淡入过渡
const Duration hoverTransition = Duration(milliseconds: 140);

/// 反向折叠过渡
const Duration reverseTransition = Duration(milliseconds: 190);

/// 主题切换动画
const Duration themeTransition = Duration(milliseconds: 200);

/// 通知条出现/消失动画
const Duration notificationTransition = Duration(milliseconds: 220);

/// 展开 / 折叠面板
const Duration expandCollapseTransition = Duration(milliseconds: 240);

/// 任务执行状态刷新间隔
const Duration executionRefreshInterval = Duration(seconds: 1);

/// 通知中心自动清除前的等待
const Duration notificationCenterClearDelay = Duration(milliseconds: 2200);

// ---------------------------------------------------------------------------
// 通知显示时长
// ---------------------------------------------------------------------------

/// 成功通知
const Duration successNotificationDisplay = Duration(seconds: 3);

/// 普通通知
const Duration defaultNotificationDisplay = Duration(seconds: 5);

/// 警告通知
const Duration warningNotificationDisplay = Duration(seconds: 6);

/// 错误通知
const Duration errorNotificationDisplay = Duration(seconds: 8);

// ---------------------------------------------------------------------------
// 更新相关
// ---------------------------------------------------------------------------

/// 默认更新频道
const String defaultUpdateChannelKey = 'stable';

/// Windows 安装器平台标识
const String windowsUpdatePlatform = 'windows-installer';

/// macOS 更新平台标识
const String macosUpdatePlatform = 'macos-universal2';

/// Linux 更新平台标识
const String linuxUpdatePlatform = 'linux-x64';

/// 未知平台标识
const String unknownUpdatePlatform = 'unknown';

/// Sparkle Appcast API 路径模板
const String sparkleAppcastApiPath = '/api/v1/sparkle/appcast';

// ---------------------------------------------------------------------------
// 布局
// ---------------------------------------------------------------------------

/// 顶栏高度
const double topBarHeight = 52;

// ---------------------------------------------------------------------------
// 图片质量
// ---------------------------------------------------------------------------

/// 图片质量滑块档位
const List<double> imageQualityRatios = [
  0.10,
  0.20,
  0.30,
  0.40,
  0.50,
  0.60,
  0.70,
  0.80,
  0.90,
  1.00,
];

/// 默认目标体积比率
const double defaultTargetSizeRatio = 0.60;

// ---------------------------------------------------------------------------
// 外部链接
// ---------------------------------------------------------------------------

/// Gitee 仓库
const String giteeUrl = 'https://gitee.com/zhouycheng/FrameLean';

/// GitHub 仓库
const String githubUrl = 'https://github.com/zhouycheng/FrameLean';

/// 联系邮箱
const String contactEmail = 'mailto:justinzhouself@gmail.com';

/// 掘金主页
const String juejinUrl = 'https://juejin.cn/user/394062317754227';
