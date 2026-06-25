// ---------------------------------------------------------------------------
// 数据库
// ---------------------------------------------------------------------------

/// SQLite 数据库文件名
const String databaseFileName = 'framelean.sqlite';

// ---------------------------------------------------------------------------
// Method Channel 名称
// ---------------------------------------------------------------------------

/// Sparkle 更新通道 (macOS)
const String sparkleUpdateChannel = 'framelean/sparkle_update';

/// 企业版更新配置通道
const String enterpriseUpdateConfigChannel =
    'framelean/enterprise_update_config';

/// 进程控制通道 (Windows)
const String processControlChannel = 'framelean/process_control';

// ---------------------------------------------------------------------------
// 临时目录
// ---------------------------------------------------------------------------

/// 系统临时目录下的根目录名
const String tempDirPrefix = 'framelean';

/// FFmpeg 日志子目录
const String ffmpegLogsSubDir = 'framelean/ffmpeg-logs';

/// 预览帧缓存子目录
const String previewsSubDir = 'framelean/previews';

// ---------------------------------------------------------------------------
// 应用流程时序
// ---------------------------------------------------------------------------

/// 列表拖拽排序动画（代理 & 落地）
const Duration reorderAnimation = Duration(milliseconds: 250);

/// 防抖 / 节流间隔
const Duration debounceInterval = Duration(milliseconds: 500);

// ---------------------------------------------------------------------------
// 超时
// ---------------------------------------------------------------------------

/// FFmpeg/FFprobe 可用性验证超时
const Duration ffprobeValidationTimeout = Duration(seconds: 3);

/// FFprobe 媒体分析超时
const Duration ffprobeAnalysisTimeout = Duration(seconds: 20);

/// 专有音频解码器超时
const Duration audioDecoderTimeout = Duration(minutes: 2);

// ---------------------------------------------------------------------------
// 通知来源标识
// ---------------------------------------------------------------------------

const String notificationSourceUpdate = 'update';
const String notificationSourceSettings = 'settings';
const String notificationSourceWorkbench = 'workbench';
const String notificationSourceTask = 'task';

// ---------------------------------------------------------------------------
// 预览帧
// ---------------------------------------------------------------------------

/// 默认预览帧时间比率（0.0 ~ 1.0 相对于视频总时长）
const List<double> defaultPreviewFrameRatios = [0.05, 0.275, 0.5, 0.725, 0.95];

// ---------------------------------------------------------------------------
// 日志
// ---------------------------------------------------------------------------

/// 执行日志单次最大读取字节数 (1 MB)
const int maxLogReadBytes = 1024 * 1024;
