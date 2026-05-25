import 'package:machining/domain/enums/media_kind.dart';
import 'package:machining/domain/enums/task_purpose.dart';
import 'package:machining/domain/enums/task_status.dart';
import 'package:machining/domain/value_objects/video_task_config.dart';
import 'package:machining/domain/value_objects/media_analysis_result.dart';
import 'package:machining/domain/value_objects/source_file_fingerprint.dart';
import 'package:uuid/uuid.dart';

class MediaTask {
  final String id;
  final String inputPath;
  final String fileName;
  final MediaKind mediaKind;
  final TaskPurpose purpose;
  final TaskStatus status;
  final VideoTaskConfig config;
  final double progress;
  final int sortOrder;
  final String? outputPath;
  final String? errorMessage;
  final SourceFileFingerprint? sourceFileFingerprint;
  final MediaAnalysisResult? analysisResult;
  final int? analysisUpdatedAt;
  final String? analysisErrorMessage;
  final int createdAt;
  final int? startedAt;
  final int? completedAt;
  final int? failedAt;

  /// 生成任务唯一 ID
  static String generateId() => Uuid().v4();

  /// 创建刚导入、尚未开始处理的草稿任务
  factory MediaTask.draft({
    required String inputPath,
    required String fileName,
    required MediaKind mediaKind,
    required int sortOrder,
    TaskPurpose purpose = TaskPurpose.compression,
    VideoTaskConfig? config,
  }) {
    return MediaTask(
      id: generateId(),
      inputPath: inputPath,
      fileName: fileName,
      mediaKind: mediaKind,
      purpose: purpose,
      status: TaskStatus.pending,
      config: config ?? VideoTaskConfig.initial(),
      progress: 0,
      sortOrder: sortOrder,
    );
  }

  MediaTask({
    required this.id,
    required this.inputPath,
    required this.fileName,
    required this.mediaKind,
    required this.purpose,
    required this.status,
    required this.config,
    required this.progress,
    required this.sortOrder,
    int? createdAt,
    this.outputPath,
    this.errorMessage,
    this.sourceFileFingerprint,
    this.analysisResult,
    this.analysisUpdatedAt,
    this.analysisErrorMessage,
    this.startedAt,
    this.completedAt,
    this.failedAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
       assert(progress >= 0 && progress <= 1);

  MediaTask copyWith({
    String? id,
    String? inputPath,
    String? fileName,
    MediaKind? mediaKind,
    TaskPurpose? purpose,
    TaskStatus? status,
    VideoTaskConfig? config,
    double? progress,
    int? sortOrder,
    String? outputPath,
    String? errorMessage,
    SourceFileFingerprint? sourceFileFingerprint,
    MediaAnalysisResult? analysisResult,
    int? analysisUpdatedAt,
    String? analysisErrorMessage,
    int? createdAt,
    int? startedAt,
    int? completedAt,
    int? failedAt,
  }) {
    return MediaTask(
      id: id ?? this.id,
      inputPath: inputPath ?? this.inputPath,
      fileName: fileName ?? this.fileName,
      mediaKind: mediaKind ?? this.mediaKind,
      purpose: purpose ?? this.purpose,
      status: status ?? this.status,
      config: config ?? this.config,
      progress: progress ?? this.progress,
      sortOrder: sortOrder ?? this.sortOrder,
      outputPath: outputPath ?? this.outputPath,
      errorMessage: errorMessage ?? this.errorMessage,
      sourceFileFingerprint:
          sourceFileFingerprint ?? this.sourceFileFingerprint,
      analysisResult: analysisResult ?? this.analysisResult,
      analysisUpdatedAt: analysisUpdatedAt ?? this.analysisUpdatedAt,
      analysisErrorMessage: analysisErrorMessage ?? this.analysisErrorMessage,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      failedAt: failedAt ?? this.failedAt,
    );
  }

  /// 清空错误信息和失败时间
  MediaTask clearError() {
    return MediaTask(
      id: id,
      inputPath: inputPath,
      fileName: fileName,
      mediaKind: mediaKind,
      purpose: purpose,
      status: status,
      config: config,
      progress: progress,
      sortOrder: sortOrder,
      outputPath: outputPath,
      errorMessage: null,
      sourceFileFingerprint: sourceFileFingerprint,
      analysisResult: analysisResult,
      analysisUpdatedAt: analysisUpdatedAt,
      analysisErrorMessage: null,
      createdAt: createdAt,
      startedAt: startedAt,
      completedAt: completedAt,
      failedAt: null,
    );
  }

  /// 把任务重置成待重试状态
  MediaTask markPendingForRetry() {
    return MediaTask(
      id: id,
      inputPath: inputPath,
      fileName: fileName,
      mediaKind: mediaKind,
      purpose: purpose,
      status: TaskStatus.pending,
      config: config,
      progress: 0,
      sortOrder: sortOrder,
      outputPath: outputPath,
      errorMessage: null,
      sourceFileFingerprint: sourceFileFingerprint,
      analysisResult: analysisResult,
      analysisUpdatedAt: analysisUpdatedAt,
      analysisErrorMessage: analysisErrorMessage,
      createdAt: createdAt,
      startedAt: null,
      completedAt: null,
      failedAt: null,
    );
  }

  /// 标记源文件丢失，任务会在列表里显示为需要用户重新指定文件
  MediaTask markMissingSource() {
    return MediaTask(
      id: id,
      inputPath: inputPath,
      fileName: fileName,
      mediaKind: mediaKind,
      purpose: purpose,
      status: TaskStatus.missingSource,
      config: config,
      progress: progress,
      sortOrder: sortOrder,
      outputPath: outputPath,
      errorMessage: errorMessage,
      sourceFileFingerprint: sourceFileFingerprint,
      analysisResult: analysisResult,
      analysisUpdatedAt: analysisUpdatedAt,
      analysisErrorMessage: analysisErrorMessage,
      createdAt: createdAt,
      startedAt: startedAt,
      completedAt: completedAt,
      failedAt: failedAt,
    );
  }

  /// 标记任务已经交给 FFmpeg 进程执行
  MediaTask markRunning({required String outputPath, int? startedAt}) {
    return MediaTask(
      id: id,
      inputPath: inputPath,
      fileName: fileName,
      mediaKind: mediaKind,
      purpose: purpose,
      status: TaskStatus.running,
      config: config,
      progress: 0,
      sortOrder: sortOrder,
      outputPath: outputPath,
      errorMessage: null,
      sourceFileFingerprint: sourceFileFingerprint,
      analysisResult: analysisResult,
      analysisUpdatedAt: analysisUpdatedAt,
      analysisErrorMessage: analysisErrorMessage,
      createdAt: createdAt,
      startedAt: startedAt ?? DateTime.now().millisecondsSinceEpoch,
      completedAt: null,
      failedAt: null,
    );
  }

  /// 标记任务启动或执行失败
  MediaTask markFailed(String message, {int? failedAt}) {
    return MediaTask(
      id: id,
      inputPath: inputPath,
      fileName: fileName,
      mediaKind: mediaKind,
      purpose: purpose,
      status: TaskStatus.failed,
      config: config,
      progress: progress,
      sortOrder: sortOrder,
      outputPath: outputPath,
      errorMessage: message,
      sourceFileFingerprint: sourceFileFingerprint,
      analysisResult: analysisResult,
      analysisUpdatedAt: analysisUpdatedAt,
      analysisErrorMessage: analysisErrorMessage,
      createdAt: createdAt,
      startedAt: startedAt,
      completedAt: completedAt,
      failedAt: failedAt ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 标记任务进程已挂起，后续可以从当前进程恢复
  MediaTask markPaused() {
    return MediaTask(
      id: id,
      inputPath: inputPath,
      fileName: fileName,
      mediaKind: mediaKind,
      purpose: purpose,
      status: TaskStatus.paused,
      config: config,
      progress: progress,
      sortOrder: sortOrder,
      outputPath: outputPath,
      errorMessage: null,
      sourceFileFingerprint: sourceFileFingerprint,
      analysisResult: analysisResult,
      analysisUpdatedAt: analysisUpdatedAt,
      analysisErrorMessage: analysisErrorMessage,
      createdAt: createdAt,
      startedAt: startedAt,
      completedAt: completedAt,
      failedAt: null,
    );
  }

  /// 标记已挂起任务恢复到前台执行
  MediaTask markResumed() {
    return MediaTask(
      id: id,
      inputPath: inputPath,
      fileName: fileName,
      mediaKind: mediaKind,
      purpose: purpose,
      status: TaskStatus.running,
      config: config,
      progress: progress,
      sortOrder: sortOrder,
      outputPath: outputPath,
      errorMessage: null,
      sourceFileFingerprint: sourceFileFingerprint,
      analysisResult: analysisResult,
      analysisUpdatedAt: analysisUpdatedAt,
      analysisErrorMessage: analysisErrorMessage,
      createdAt: createdAt,
      startedAt: startedAt ?? DateTime.now().millisecondsSinceEpoch,
      completedAt: null,
      failedAt: null,
    );
  }

  /// 标记任务被用户取消
  MediaTask markCancelled() {
    return MediaTask(
      id: id,
      inputPath: inputPath,
      fileName: fileName,
      mediaKind: mediaKind,
      purpose: purpose,
      status: TaskStatus.cancelled,
      config: config,
      progress: progress,
      sortOrder: sortOrder,
      outputPath: outputPath,
      errorMessage: null,
      sourceFileFingerprint: sourceFileFingerprint,
      analysisResult: analysisResult,
      analysisUpdatedAt: analysisUpdatedAt,
      analysisErrorMessage: analysisErrorMessage,
      createdAt: createdAt,
      startedAt: startedAt,
      completedAt: completedAt,
      failedAt: failedAt,
    );
  }

  /// 更新运行中任务的处理进度
  MediaTask withProgress(double value) {
    final normalizedProgress = value.clamp(0, 1).toDouble();

    return MediaTask(
      id: id,
      inputPath: inputPath,
      fileName: fileName,
      mediaKind: mediaKind,
      purpose: purpose,
      status: status,
      config: config,
      progress: normalizedProgress,
      sortOrder: sortOrder,
      outputPath: outputPath,
      errorMessage: errorMessage,
      sourceFileFingerprint: sourceFileFingerprint,
      analysisResult: analysisResult,
      analysisUpdatedAt: analysisUpdatedAt,
      analysisErrorMessage: analysisErrorMessage,
      createdAt: createdAt,
      startedAt: startedAt,
      completedAt: completedAt,
      failedAt: failedAt,
    );
  }

  /// 标记任务执行完成
  MediaTask markCompleted({int? completedAt}) {
    return MediaTask(
      id: id,
      inputPath: inputPath,
      fileName: fileName,
      mediaKind: mediaKind,
      purpose: purpose,
      status: TaskStatus.completed,
      config: config,
      progress: 1,
      sortOrder: sortOrder,
      outputPath: outputPath,
      errorMessage: null,
      sourceFileFingerprint: sourceFileFingerprint,
      analysisResult: analysisResult,
      analysisUpdatedAt: analysisUpdatedAt,
      analysisErrorMessage: analysisErrorMessage,
      createdAt: createdAt,
      startedAt: startedAt,
      completedAt: completedAt ?? DateTime.now().millisecondsSinceEpoch,
      failedAt: null,
    );
  }

  /// 重新指定丢失的源文件
  MediaTask replaceInputFile({
    required String newInputPath,
    required String newFileName,
    required MediaKind newMediaKind,
  }) {
    if (newMediaKind != mediaKind) {
      throw StateError('重新指定的文件类型必须是 ${mediaKind.name}');
    }

    return MediaTask(
      id: id,
      inputPath: newInputPath,
      fileName: newFileName,
      mediaKind: mediaKind,
      purpose: purpose,
      status: TaskStatus.pending,
      config: config,
      progress: 0,
      sortOrder: sortOrder,
      outputPath: null,
      errorMessage: null,
      sourceFileFingerprint: null,
      analysisResult: null,
      analysisUpdatedAt: null,
      analysisErrorMessage: null,
      createdAt: createdAt,
      startedAt: null,
      completedAt: null,
      failedAt: null,
    );
  }

  /// 保存源文件指纹
  MediaTask withSourceFileFingerprint(SourceFileFingerprint fingerprint) {
    return MediaTask(
      id: id,
      inputPath: inputPath,
      fileName: fileName,
      mediaKind: mediaKind,
      purpose: purpose,
      status: status,
      config: config,
      progress: progress,
      sortOrder: sortOrder,
      outputPath: outputPath,
      errorMessage: errorMessage,
      sourceFileFingerprint: fingerprint,
      analysisResult: analysisResult,
      analysisUpdatedAt: analysisUpdatedAt,
      analysisErrorMessage: analysisErrorMessage,
      createdAt: createdAt,
      startedAt: startedAt,
      completedAt: completedAt,
      failedAt: failedAt,
    );
  }

  /// 保存媒体分析结果
  MediaTask withAnalysisResult(MediaAnalysisResult result) {
    return MediaTask(
      id: id,
      inputPath: inputPath,
      fileName: fileName,
      mediaKind: mediaKind,
      purpose: purpose,
      status: status,
      config: config,
      progress: progress,
      sortOrder: sortOrder,
      outputPath: outputPath,
      errorMessage: errorMessage,
      sourceFileFingerprint: sourceFileFingerprint,
      analysisResult: result,
      analysisUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      analysisErrorMessage: null,
      createdAt: createdAt,
      startedAt: startedAt,
      completedAt: completedAt,
      failedAt: failedAt,
    );
  }

  /// 保存媒体分析错误
  MediaTask withAnalysisError(String message) {
    return MediaTask(
      id: id,
      inputPath: inputPath,
      fileName: fileName,
      mediaKind: mediaKind,
      purpose: purpose,
      status: status,
      config: config,
      progress: progress,
      sortOrder: sortOrder,
      outputPath: outputPath,
      errorMessage: errorMessage,
      sourceFileFingerprint: sourceFileFingerprint,
      analysisResult: analysisResult,
      analysisUpdatedAt: analysisUpdatedAt,
      analysisErrorMessage: message,
      createdAt: createdAt,
      startedAt: startedAt,
      completedAt: completedAt,
      failedAt: failedAt,
    );
  }

  /// 清空旧媒体分析结果
  MediaTask clearAnalysis() {
    return MediaTask(
      id: id,
      inputPath: inputPath,
      fileName: fileName,
      mediaKind: mediaKind,
      purpose: purpose,
      status: status,
      config: config,
      progress: progress,
      sortOrder: sortOrder,
      outputPath: outputPath,
      errorMessage: errorMessage,
      sourceFileFingerprint: sourceFileFingerprint,
      analysisResult: null,
      analysisUpdatedAt: null,
      analysisErrorMessage: null,
      createdAt: createdAt,
      startedAt: startedAt,
      completedAt: completedAt,
      failedAt: failedAt,
    );
  }
}
