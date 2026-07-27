import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/media_task_policy_tag.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/value_objects/media_analysis_result.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/domain/value_objects/source_file_fingerprint.dart';
import 'package:framelean/domain/value_objects/task_failure.dart';
import 'package:uuid/uuid.dart';

class MediaTask {
  final String id;
  final String inputPath;
  final String fileName;
  final MediaKind mediaKind;
  final TaskPurpose purpose;
  final TaskStatus status;
  final MediaTaskConfig config;
  final double progress;
  final int sortOrder;
  final String? folderId;
  final int? folderSortOrder;
  final String? outputPath;
  final int? outputFileSize;
  final TaskFailure? failure;
  final Set<MediaTaskPolicyTag> policyTags;
  final SourceFileFingerprint? sourceFileFingerprint;
  final MediaAnalysisResult? analysisResult;
  final int? analysisUpdatedAt;
  final int createdAt;
  final int? startedAt;
  final int? completedAt;
  final int? failedAt;

  /// 生成任务唯一 ID
  static String generateId() => Uuid().v4();

  static const Set<MediaTaskPolicyTag> _executionPolicyTags = {
    MediaTaskPolicyTag.outputRenamed,
    MediaTaskPolicyTag.outputDirectoryCreated,
    MediaTaskPolicyTag.imageFormatFallback,
    MediaTaskPolicyTag.ineffectiveCompression,
  };

  /// 创建刚导入、尚未开始处理的草稿任务
  factory MediaTask.draft({
    required String inputPath,
    required String fileName,
    required MediaKind mediaKind,
    required int sortOrder,
    TaskPurpose purpose = TaskPurpose.compression,
    Object? config,
  }) {
    return MediaTask(
      id: generateId(),
      inputPath: inputPath,
      fileName: fileName,
      mediaKind: mediaKind,
      purpose: purpose,
      status: TaskStatus.awaitAnalysis,
      config: MediaTaskConfig.normalize(config, mediaKind),
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
    required Object config,
    required this.progress,
    required this.sortOrder,
    this.folderId,
    this.folderSortOrder,
    int? createdAt,
    this.outputPath,
    this.outputFileSize,
    this.failure,
    Set<MediaTaskPolicyTag> policyTags = const {},
    this.sourceFileFingerprint,
    this.analysisResult,
    this.analysisUpdatedAt,
    this.startedAt,
    this.completedAt,
    this.failedAt,
  }) : config = MediaTaskConfig.normalize(config, mediaKind),
       policyTags = Set.unmodifiable(policyTags),
       createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
       assert(progress >= 0 && progress <= 1) {
    if (!this.config.isValidFor(mediaKind)) {
      throw StateError('媒体任务配置与媒体类型不匹配: ${mediaKind.name}');
    }
  }

  MediaTask copyWith({
    String? id,
    String? inputPath,
    String? fileName,
    MediaKind? mediaKind,
    TaskPurpose? purpose,
    TaskStatus? status,
    Object? config,
    double? progress,
    int? sortOrder,
    String? folderId,
    int? folderSortOrder,
    bool clearFolder = false,
    String? outputPath,
    bool clearOutputPath = false,
    int? outputFileSize,
    bool clearOutputFileSize = false,
    TaskFailure? failure,
    bool clearFailure = false,
    Set<MediaTaskPolicyTag>? policyTags,
    SourceFileFingerprint? sourceFileFingerprint,
    bool clearSourceFileFingerprint = false,
    MediaAnalysisResult? analysisResult,
    bool clearAnalysisResult = false,
    int? analysisUpdatedAt,
    bool clearAnalysisUpdatedAt = false,
    int? createdAt,
    int? startedAt,
    bool clearStartedAt = false,
    int? completedAt,
    bool clearCompletedAt = false,
    int? failedAt,
    bool clearFailedAt = false,
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
      folderId: clearFolder ? null : folderId ?? this.folderId,
      folderSortOrder: clearFolder
          ? null
          : folderSortOrder ?? this.folderSortOrder,
      outputPath: clearOutputPath ? null : outputPath ?? this.outputPath,
      outputFileSize: clearOutputFileSize
          ? null
          : outputFileSize ?? this.outputFileSize,
      failure: clearFailure ? null : failure ?? this.failure,
      policyTags: policyTags ?? this.policyTags,
      sourceFileFingerprint: clearSourceFileFingerprint
          ? null
          : sourceFileFingerprint ?? this.sourceFileFingerprint,
      analysisResult: clearAnalysisResult
          ? null
          : analysisResult ?? this.analysisResult,
      analysisUpdatedAt: clearAnalysisUpdatedAt
          ? null
          : analysisUpdatedAt ?? this.analysisUpdatedAt,
      createdAt: createdAt ?? this.createdAt,
      startedAt: clearStartedAt ? null : startedAt ?? this.startedAt,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      failedAt: clearFailedAt ? null : failedAt ?? this.failedAt,
    );
  }

  String? get errorMessage => failure?.technicalSummary;

  String? get analysisErrorMessage =>
      failure?.stage == TaskFailureStage.analysis ? failure?.userMessage : null;

  bool get isAwaitingAnalysis => status == TaskStatus.awaitAnalysis;

  bool get isAnalysisReady =>
      status == TaskStatus.ready && analysisResult != null;

  /// 是否满足一次全新执行的领域准入条件。
  ///
  /// `paused` 只能由 Runner 在仍持有对应 TaskExecution 时恢复，不能作为
  /// 数据库任务重新启动。
  bool get canStartExecution => isAnalysisReady;

  /// 清空错误信息和失败时间
  MediaTask clearError() {
    return copyWith(clearFailure: true, clearFailedAt: true);
  }

  /// 把任务重置成待重试状态
  MediaTask markPendingForRetry() {
    return copyWith(
      status: analysisResult == null
          ? TaskStatus.awaitAnalysis
          : TaskStatus.ready,
      progress: 0,
      clearFailure: true,
      clearStartedAt: true,
      clearCompletedAt: true,
      clearFailedAt: true,
      clearOutputFileSize: true,
      policyTags: policyTags.difference(_executionPolicyTags),
    );
  }

  MediaTask markAwaitingAnalysis() {
    return copyWith(
      status: TaskStatus.awaitAnalysis,
      progress: 0,
      clearFailure: true,
      clearStartedAt: true,
      clearCompletedAt: true,
      clearFailedAt: true,
      clearOutputFileSize: true,
    );
  }

  MediaTask markAnalysisQueued() {
    if (status != TaskStatus.awaitAnalysis) {
      return this;
    }
    return copyWith(status: TaskStatus.analysisQueued, clearFailure: true);
  }

  /// 标记分析队列已经取得该任务的执行位。
  MediaTask markAnalyzing() {
    if (status != TaskStatus.awaitAnalysis &&
        status != TaskStatus.analysisQueued) {
      return this;
    }
    return copyWith(status: TaskStatus.analyzing);
  }

  /// 分析完成后恢复为可执行的等待状态。
  MediaTask markAnalysisReady() {
    if (status != TaskStatus.awaitAnalysis &&
        status != TaskStatus.analysisQueued &&
        status != TaskStatus.analyzing) {
      return this;
    }
    if (analysisResult == null) {
      return this;
    }
    return copyWith(status: TaskStatus.ready, clearFailure: true);
  }

  MediaTask markAnalysisFailed(TaskFailure failure, {int? failedAt}) {
    return copyWith(
      status: TaskStatus.analysisFailed,
      failure: failure,
      failedAt: failedAt ?? failure.occurredAt,
    );
  }

  MediaTask markExecutionQueued() {
    if (status != TaskStatus.ready) {
      return this;
    }
    return copyWith(
      status: TaskStatus.executionQueued,
      progress: 0,
      clearFailure: true,
      clearFailedAt: true,
    );
  }

  MediaTask markPreempting() => copyWith(status: TaskStatus.preempting);

  MediaTask markPreempted() => copyWith(status: TaskStatus.preempted);

  MediaTask markResuming() => copyWith(status: TaskStatus.resuming);

  /// 标记源文件丢失，任务会在列表里显示为需要用户重新指定文件
  MediaTask markMissingSource() {
    return copyWith(status: TaskStatus.missingSource, clearFailure: true);
  }

  /// 标记任务已经交给 FEngine 执行。
  MediaTask markRunning({required String outputPath, int? startedAt}) {
    return copyWith(
      status: TaskStatus.running,
      progress: 0,
      outputPath: outputPath,
      clearFailure: true,
      startedAt: startedAt ?? DateTime.now().millisecondsSinceEpoch,
      clearCompletedAt: true,
      clearFailedAt: true,
      clearOutputFileSize: true,
    );
  }

  /// 标记任务启动或执行失败
  MediaTask markFailed(TaskFailure failure, {int? failedAt}) {
    return copyWith(
      status: TaskStatus.executionFailed,
      failure: failure,
      failedAt: failedAt ?? failure.occurredAt,
    );
  }

  /// 标记任务进程已挂起，后续可以从当前进程恢复
  MediaTask markPaused() {
    return copyWith(
      status: TaskStatus.paused,
      clearFailure: true,
      clearFailedAt: true,
    );
  }

  /// 标记已挂起任务恢复到前台执行
  MediaTask markResumed() {
    return copyWith(
      status: TaskStatus.running,
      clearFailure: true,
      startedAt: startedAt ?? DateTime.now().millisecondsSinceEpoch,
      clearCompletedAt: true,
      clearFailedAt: true,
    );
  }

  /// 标记任务被用户取消
  MediaTask markCancelled() {
    return copyWith(status: TaskStatus.cancelled, clearFailure: true);
  }

  /// 更新运行中任务的处理进度
  MediaTask withProgress(double value) {
    final normalizedProgress = value.clamp(0, 1).toDouble();

    return copyWith(progress: normalizedProgress);
  }

  /// 标记任务执行完成
  MediaTask markCompleted({int? completedAt, int? outputFileSize}) {
    return copyWith(
      status: TaskStatus.completed,
      progress: 1,
      outputFileSize: outputFileSize,
      clearOutputFileSize: outputFileSize == null,
      clearFailure: true,
      completedAt: completedAt ?? DateTime.now().millisecondsSinceEpoch,
      clearFailedAt: true,
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

    return copyWith(
      inputPath: newInputPath,
      fileName: newFileName,
      config: config.copyWith(engineConfiguration: null),
      status: TaskStatus.awaitAnalysis,
      progress: 0,
      clearOutputPath: true,
      clearOutputFileSize: true,
      clearFailure: true,
      clearSourceFileFingerprint: true,
      clearAnalysisResult: true,
      clearAnalysisUpdatedAt: true,
      clearStartedAt: true,
      clearCompletedAt: true,
      clearFailedAt: true,
      policyTags: const {},
    );
  }

  /// 保存源文件指纹
  MediaTask withSourceFileFingerprint(SourceFileFingerprint fingerprint) {
    return copyWith(sourceFileFingerprint: fingerprint);
  }

  /// 保存媒体分析结果
  MediaTask withAnalysisResult(MediaAnalysisResult result) {
    final tags = {...policyTags}
      ..remove(MediaTaskPolicyTag.transparentPreserve);
    if (result.videoPixelFormat != null &&
        _pixelFormatContainsAlpha(result.videoPixelFormat!)) {
      tags.add(MediaTaskPolicyTag.transparentPreserve);
    }

    return copyWith(
      analysisResult: result,
      analysisUpdatedAt: DateTime.now().millisecondsSinceEpoch,
      clearFailure: true,
      policyTags: tags,
    );
  }

  /// 清空旧媒体分析结果
  MediaTask clearAnalysis() {
    final tags = {...policyTags}
      ..remove(MediaTaskPolicyTag.transparentPreserve);
    return copyWith(
      config: config.copyWith(engineConfiguration: null),
      clearAnalysisResult: true,
      clearAnalysisUpdatedAt: true,
      clearFailure: true,
      policyTags: tags,
    );
  }

  MediaTask withPolicyTags(Iterable<MediaTaskPolicyTag> tags) {
    return copyWith(policyTags: {...policyTags, ...tags});
  }

  MediaTask moveToFolder({
    required String targetFolderId,
    required int targetFolderSortOrder,
  }) {
    return copyWith(
      folderId: targetFolderId,
      folderSortOrder: targetFolderSortOrder,
    );
  }

  MediaTask releaseFromFolder({int? newSortOrder}) {
    return copyWith(sortOrder: newSortOrder, clearFolder: true);
  }

  static bool _pixelFormatContainsAlpha(String pixelFormat) {
    final normalized = pixelFormat.trim().toLowerCase();
    return normalized.startsWith('yuva') ||
        normalized == 'rgba' ||
        normalized == 'bgra' ||
        normalized == 'argb' ||
        normalized == 'abgr' ||
        normalized.startsWith('gbrap');
  }
}
