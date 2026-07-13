/// 输出处理失败阶段标识。
///
/// 用于精确定位媒体任务在输出管线的哪个步骤失败，
/// 避免所有失败都被统一报告为"输出目录不可写"。
enum OutputFailureStage {
  createOutputDirectory,
  createProbeFile,
  writeProbeFile,
  renameProbeFile,
  deleteProbeFile,
  createWorkingFile,
  setWorkingFileHidden,
  startFfmpeg,
  ffmpegProcessing,
  publishOutputFile,
  removeHiddenAttribute,
  cleanupWorkingFile,
}

/// 输出错误分类码。
///
/// 每个码对应一种具体的失败原因，用户界面应根据此码
/// 展示针对性的错误提示和建议。
enum OutputErrorCode {
  outputDirectoryCreationFailed,
  outputDirectoryNotWritable,
  invalidOutputPath,
  workingFileCreationFailed,
  ffmpegExecutableNotFound,
  ffmpegStartFailed,
  ffmpegOutputOpenFailed,
  outputFileInUse,
  outputFileAlreadyExists,
  outputPublishFailed,
  insufficientDiskSpace,
  securitySoftwareBlocked,
  cleanupFailed,
  unknownFileSystemError,
}

/// 输出失败对象，包含完整的诊断信息。
///
/// [userMessage] 是面向用户的简洁提示；
/// [technicalMessage] 保留原始技术信息供日志和调试使用。
class OutputFailure {
  final OutputErrorCode code;
  final OutputFailureStage stage;
  final String userMessage;
  final String technicalMessage;
  final String? path;
  final int? osErrorCode;
  final int? processExitCode;
  final String? processStderr;
  final Object? originalError;
  final StackTrace? stackTrace;

  const OutputFailure({
    required this.code,
    required this.stage,
    required this.userMessage,
    required this.technicalMessage,
    this.path,
    this.osErrorCode,
    this.processExitCode,
    this.processStderr,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => technicalMessage;
}

/// 将 Windows OS 错误码映射为对应的 [OutputErrorCode]。
///
/// 参考 Windows System Error Codes:
/// - 2: 文件或路径不存在
/// - 3: 找不到路径
/// - 5: 拒绝访问
/// - 32: 文件正在被其他进程使用
/// - 80: 文件已存在
/// - 112: 磁盘空间不足
/// - 123: 文件名、目录名或卷标语法错误
/// - 183: 文件已存在
/// - 206: 路径或文件名过长
OutputErrorCode mapWindowsOsErrorCode(int errorCode) {
  switch (errorCode) {
    case 2:
    case 3:
      return OutputErrorCode.invalidOutputPath;
    case 5:
      return OutputErrorCode.outputDirectoryNotWritable;
    case 32:
      return OutputErrorCode.outputFileInUse;
    case 80:
    case 183:
      return OutputErrorCode.outputFileAlreadyExists;
    case 112:
      return OutputErrorCode.insufficientDiskSpace;
    case 123:
    case 206:
      return OutputErrorCode.invalidOutputPath;
    default:
      return OutputErrorCode.unknownFileSystemError;
  }
}

/// 判断错误文本是否包含权限拒绝相关关键词。
bool isPermissionDeniedText(String text) {
  final lower = text.toLowerCase();
  return lower.contains('permission denied') ||
      lower.contains('access is denied') ||
      lower.contains('operation not permitted') ||
      lower.contains('无法访问') ||
      lower.contains('拒绝访问');
}

/// 判断错误文本是否可能是安全软件拦截。
bool isSecuritySoftwareBlockText(String text) {
  final lower = text.toLowerCase();
  return isPermissionDeniedText(text) &&
      (lower.contains('ffmpeg') || lower.contains('ffmpeg.exe'));
}
