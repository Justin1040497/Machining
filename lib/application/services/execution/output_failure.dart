import 'package:framelean/domain/library.dart';

TaskFailureCode mapWindowsOsErrorCode(int errorCode) {
  return switch (errorCode) {
    2 || 3 || 123 || 206 => TaskFailureCode.invalidOutputPath,
    5 => TaskFailureCode.outputDirectoryNotWritable,
    32 || 80 || 183 => TaskFailureCode.outputFileInUse,
    112 => TaskFailureCode.insufficientDiskSpace,
    _ => TaskFailureCode.unknown,
  };
}

bool isPermissionDeniedText(String text) {
  final lower = text.toLowerCase();
  return lower.contains('permission denied') ||
      lower.contains('access is denied') ||
      lower.contains('operation not permitted') ||
      lower.contains('无法访问') ||
      lower.contains('拒绝访问');
}

bool isSecuritySoftwareBlockText(String text) {
  final lower = text.toLowerCase();
  return isPermissionDeniedText(text) &&
      (lower.contains('ffmpeg') || lower.contains('ffmpeg.exe'));
}

TaskFailure taskFailureFromError({
  required TaskFailureStage stage,
  required String technicalSummary,
  required int occurredAt,
  MediaKind? mediaKind,
  TaskFailureCode? fallbackCode,
  String? fallbackUserMessage,
  bool retryable = true,
}) {
  final raw = technicalSummary.trim();
  final lower = raw.toLowerCase();
  var code = fallbackCode ?? TaskFailureCode.unknown;
  var userMessage = fallbackUserMessage ?? '媒体处理未能完成';

  if (raw.contains('不小于源文件') || raw.contains('未有效压缩') || raw.contains('无法验证')) {
    code = TaskFailureCode.ineffectiveCompression;
    userMessage = raw;
    retryable = false;
  } else if (raw.contains('临时输出文件被删除或移动')) {
    code = TaskFailureCode.processInterrupted;
    userMessage = '运行中的临时输出文件被删除或移动，任务已停止。';
  } else if (raw.contains('无响应超时') || raw.contains('进度停滞超时')) {
    code = TaskFailureCode.processStalled;
    userMessage = '处理进程长时间没有有效进度，已自动终止。';
  } else if ((lower.contains('videotoolbox') ||
          lower.contains('nvenc') ||
          lower.contains('_qsv') ||
          lower.contains('_amf')) &&
      (lower.contains('generic error in an external library') ||
          raw.contains('硬件编码器会话失效'))) {
    code = TaskFailureCode.hardwareSessionLost;
    userMessage = '系统挂起或睡眠导致硬件编码会话中断。';
  } else if (lower.contains('no space left on device') ||
      lower.contains('disk full') ||
      raw.contains('磁盘空间不足') ||
      lower.contains('not enough space')) {
    code = TaskFailureCode.insufficientDiskSpace;
    userMessage = '磁盘空间不足，无法写入输出文件。';
  } else if (isSecuritySoftwareBlockText(raw)) {
    code = TaskFailureCode.securitySoftwareBlocked;
    userMessage = 'FFmpeg 无法写入所选目录，可能被系统安全策略拦截。';
  } else if (isPermissionDeniedText(raw) ||
      lower.contains('directory not writable') ||
      raw.contains('输出目录不可写')) {
    code = TaskFailureCode.outputDirectoryNotWritable;
    userMessage = '没有输出位置的写入权限。';
  } else if (lower.contains('being used by another process') ||
      lower.contains('sharing violation') ||
      lower.contains('file in use') ||
      raw.contains('被占用')) {
    code = TaskFailureCode.outputFileInUse;
    userMessage = '输出文件正在被其他程序使用。';
  } else if (raw.contains('输出文件发布失败') ||
      lower.contains('failed to publish output') ||
      lower.contains('failed to rename')) {
    code = TaskFailureCode.outputPublishFailed;
    userMessage = '媒体处理已完成，但临时文件无法发布为最终文件。';
  } else if (raw.contains('最终输出文件不存在、为空或不可读') || raw.contains('输出文件缺失')) {
    code = raw.contains('不可读')
        ? TaskFailureCode.outputUnreadable
        : TaskFailureCode.outputMissing;
    userMessage = '处理结果不存在、为空或无法读取。';
  } else if (lower.contains('unknown encoder') ||
      lower.contains('encoder not found') ||
      lower.contains('not currently supported in build') ||
      raw.contains('不支持所需的编码器')) {
    code = TaskFailureCode.encoderUnavailable;
    userMessage = '当前 FFmpeg 不支持任务所需的编码器。';
    retryable = false;
  } else if (lower.contains('invalid data found') ||
      lower.contains('moov atom not found') ||
      lower.contains('malformed') ||
      lower.contains('truncated')) {
    code = TaskFailureCode.corruptMedia;
    userMessage = '源文件可能已损坏或格式不受支持。';
    retryable = false;
  } else if (lower.contains('no such file or directory') ||
      lower.contains('could not find file') ||
      raw.contains('源文件不存在')) {
    code = TaskFailureCode.sourceUnavailable;
    userMessage = '源文件不可访问，可能已被移动或移除。';
  } else if (stage == TaskFailureStage.processStart) {
    code = TaskFailureCode.processStartFailed;
    userMessage = fallbackUserMessage ?? 'FFmpeg 进程启动失败。';
  } else if (stage == TaskFailureStage.processing &&
      code == TaskFailureCode.unknown) {
    code = TaskFailureCode.processExitedAbnormally;
  }

  return TaskFailure(
    stage: stage,
    code: code,
    userMessage: userMessage,
    technicalSummary: raw.isEmpty ? userMessage : raw,
    occurredAt: occurredAt,
    retryable: retryable,
  );
}
