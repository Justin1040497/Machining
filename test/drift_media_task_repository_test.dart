import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:framelean/application/repositories/media_task_repository.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/entities/task_folder.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/media_task_policy_tag.dart';
import 'package:framelean/domain/enums/media_output_format.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/value_objects/image_processing_config.dart';
import 'package:framelean/domain/value_objects/media_analysis_result.dart';
import 'package:framelean/domain/value_objects/media_task_config.dart';
import 'package:framelean/domain/value_objects/video_task_config.dart';
import 'package:framelean/domain/value_objects/task_failure.dart';
import 'package:framelean/infrastructure/database/app_database.dart';
import 'package:framelean/infrastructure/repositories/drift_media_task_repository.dart';

void main() {
  group('DriftMediaTaskRepository mappers', () {
    test('persists structured failure and mirrors legacy columns', () {
      final failedTask = mediaTask(status: TaskStatus.failed).copyWith(
        failure: const TaskFailure(
          stage: TaskFailureStage.outputPublication,
          code: TaskFailureCode.outputPublishFailed,
          userMessage: '无法发布最终文件',
          technicalSummary: 'rename access denied',
          occurredAt: 12,
          retryable: true,
        ),
      );

      final companion = failedTask.toCompanion();
      expect(companion.failureJson.value, contains('outputPublication'));
      expect(companion.errorMessage.value, 'rename access denied');
      expect(companion.analysisErrorMessage.value, isNull);

      final restored = taskRow(
        status: 'failed',
        failureJson: companion.failureJson.value,
      ).toDomain();
      expect(restored.failure?.stage, TaskFailureStage.outputPublication);
      expect(restored.failure?.code, TaskFailureCode.outputPublishFailed);
      expect(restored.failure?.userMessage, '无法发布最终文件');
    });

    test('restores legacy failure when failure_json is absent', () {
      final restored = taskRow(
        status: 'failed',
        errorMessage: 'ffprobe stderr',
        analysisErrorMessage: '媒体分析失败',
      ).toDomain();

      expect(restored.failure?.stage, TaskFailureStage.analysis);
      expect(restored.failure?.code, TaskFailureCode.unknown);
      expect(restored.failure?.technicalSummary, 'ffprobe stderr');
    });

    test('persists extended media analysis fields from domain', () {
      final task = mediaTask(
        analysisResult: MediaAnalysisResult(
          durationMs: 1000,
          videoWidth: 1920,
          videoHeight: 1080,
          videoCodec: 'h264',
          audioCodec: 'aac',
          videoPixelFormat: 'yuv420p10le',
          videoBitDepth: 10,
          colorRange: 'tv',
          colorSpace: 'bt709',
          colorTransfer: 'bt709',
          colorPrimaries: 'bt709',
          chromaLocation: 'left',
          masteringDisplayMetadata: 'red_x=34000/50000',
          masteringDisplayMaxLuminance: 1000,
          maxContentLightLevel: 1000,
          maxFrameAverageLightLevel: 400,
          dolbyVisionProfile: 8,
          dolbyVisionCompatibilityId: 1,
          averageFrameRate: '30000/1001',
          realFrameRate: '30000/1001',
          sampleAspectRatio: '1:1',
          displayAspectRatio: '16:9',
          videoRotationDegrees: 90,
          fieldOrder: 'progressive',
          audioChannels: 2,
          audioSampleRate: 48000,
          audioChannelLayout: 'stereo',
        ),
      );

      final companion = task.toCompanion();

      expect(companion.analysisVideoPixelFormat.value, 'yuv420p10le');
      expect(companion.analysisVideoBitDepth.value, 10);
      expect(companion.analysisColorRange.value, 'tv');
      expect(companion.analysisColorSpace.value, 'bt709');
      expect(companion.analysisColorTransfer.value, 'bt709');
      expect(companion.analysisColorPrimaries.value, 'bt709');
      expect(companion.analysisChromaLocation.value, 'left');
      expect(
        companion.analysisMasteringDisplayMetadata.value,
        'red_x=34000/50000',
      );
      expect(companion.analysisMasteringDisplayMaxLuminance.value, 1000);
      expect(companion.analysisMaxContentLightLevel.value, 1000);
      expect(companion.analysisMaxFrameAverageLightLevel.value, 400);
      expect(companion.analysisDolbyVisionProfile.value, 8);
      expect(companion.analysisDolbyVisionCompatibilityId.value, 1);
      expect(companion.analysisAverageFrameRate.value, '30000/1001');
      expect(companion.analysisRealFrameRate.value, '30000/1001');
      expect(companion.analysisSampleAspectRatio.value, '1:1');
      expect(companion.analysisDisplayAspectRatio.value, '16:9');
      expect(companion.analysisVideoRotationDegrees.value, 90);
      expect(companion.analysisFieldOrder.value, 'progressive');
      expect(companion.analysisAudioChannelLayout.value, 'stereo');
    });

    test('restores extended media analysis fields to domain', () {
      final row = taskRow();

      final task = row.toDomain();
      final analysis = task.analysisResult;

      expect(analysis, isNotNull);
      expect(analysis!.videoPixelFormat, 'p010le');
      expect(analysis.videoBitDepth, 10);
      expect(analysis.colorRange, 'tv');
      expect(analysis.colorSpace, 'bt2020nc');
      expect(analysis.colorTransfer, 'smpte2084');
      expect(analysis.colorPrimaries, 'bt2020');
      expect(analysis.chromaLocation, 'left');
      expect(analysis.masteringDisplayMetadata, 'red_x=34000/50000');
      expect(analysis.masteringDisplayMaxLuminance, 1000);
      expect(analysis.maxContentLightLevel, 1000);
      expect(analysis.maxFrameAverageLightLevel, 400);
      expect(analysis.dolbyVisionProfile, 8);
      expect(analysis.dolbyVisionCompatibilityId, 1);
      expect(analysis.averageFrameRate, '60000/1001');
      expect(analysis.realFrameRate, '60000/1001');
      expect(analysis.sampleAspectRatio, '1:1');
      expect(analysis.displayAspectRatio, '16:9');
      expect(analysis.videoRotationDegrees, -90);
      expect(analysis.fieldOrder, 'progressive');
      expect(analysis.audioChannelLayout, 'stereo');
      expect(analysis.isHdr, isTrue);
    });

    test('persists and restores image media config json', () {
      final config = MediaTaskConfig.initialImage().copyWith(
        outputDirectory: '/exports',
        outputFileName: 'web-hero',
        image: ImageProcessingConfig.initial().copyWith(
          outputFormat: MediaOutputFormat.webp,
          losslessCompression: true,
          imageQuality: 74,
          resizePreset: ImageResizePreset.longEdge1920,
          preserveMetadata: true,
        ),
      );
      final task = MediaTask(
        id: 'image-task',
        inputPath: '/images/source.png',
        fileName: 'source.png',
        mediaKind: MediaKind.image,
        purpose: TaskPurpose.compression,
        status: TaskStatus.pending,
        config: config,
        progress: 0,
        sortOrder: 0,
        outputFileSize: 1024,
        createdAt: 1,
        analysisResult: MediaAnalysisResult(
          imageWidth: 1200,
          imageHeight: 800,
          imageCodec: 'png',
          imagePixelFormat: 'rgba',
          imageBitDepth: 8,
        ),
      );

      final companion = task.toCompanion();
      final restored = taskRow(
        id: 'image-task',
        inputPath: '/images/source.png',
        fileName: 'source.png',
        mediaKind: 'image',
        mediaConfigJson: companion.mediaConfigJson.value,
        outputFileSize: companion.outputFileSize.value,
        analysisImageWidth: companion.analysisImageWidth.value,
        analysisImageHeight: companion.analysisImageHeight.value,
        analysisImageCodec: companion.analysisImageCodec.value,
        analysisImagePixelFormat: companion.analysisImagePixelFormat.value,
        analysisImageBitDepth: companion.analysisImageBitDepth.value,
      ).toDomain();

      expect(companion.mediaConfigJson.value, contains('"image"'));
      expect(companion.outputFormat.value, 'mp4');
      expect(restored.mediaKind, MediaKind.image);
      expect(restored.config.outputDirectory, '/exports');
      expect(restored.config.outputFileName, 'web-hero');
      expect(restored.config.image!.outputFormat, MediaOutputFormat.webp);
      expect(restored.config.image!.losslessCompression, isTrue);
      expect(restored.config.image!.imageQuality, 74);
      expect(restored.outputFileSize, 1024);
      expect(
        restored.config.image!.resizePreset,
        ImageResizePreset.longEdge1920,
      );
      expect(restored.config.image!.preserveMetadata, isTrue);
      expect(restored.analysisResult!.imageWidth, 1200);
      expect(restored.analysisResult!.imageHeight, 800);
      expect(restored.analysisResult!.imageCodec, 'png');
      expect(restored.analysisResult!.imagePixelFormat, 'rgba');
      expect(restored.analysisResult!.imageBitDepth, 8);
    });

    test('updates only sort order fields', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftMediaTaskRepository(database);
      final runningTask = mediaTask(
        id: 'running',
        status: TaskStatus.running,
        progress: 0.5,
        sortOrder: 0,
        outputPath: '/videos/running.out.mp4',
      );
      final pendingTask = mediaTask(id: 'pending', sortOrder: 1);

      await repository.replaceAllTasks([runningTask, pendingTask]);
      await repository.updateTaskSortOrders(const [
        MediaTaskSortOrderUpdate(taskId: 'running', sortOrder: 1),
        MediaTaskSortOrderUpdate(taskId: 'pending', sortOrder: 0),
      ]);

      final tasks = await repository.loadAllTasks();
      expect(tasks.map((task) => task.id), ['pending', 'running']);
      final restoredRunning = tasks.singleWhere((task) => task.id == 'running');
      expect(restoredRunning.status, TaskStatus.running);
      expect(restoredRunning.progress, 0.5);
      expect(restoredRunning.outputPath, '/videos/running.out.mp4');
    });

    test('persists and restores task folder fields and policy tags', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftMediaTaskRepository(database);
      final task = mediaTask(id: 'foldered').copyWith(
        folderId: 'folder-1',
        folderSortOrder: 2,
        policyTags: const {
          MediaTaskPolicyTag.imageFormatFallback,
          MediaTaskPolicyTag.ineffectiveCompression,
        },
      );

      await repository.replaceAllTasks([task]);

      final restored = (await repository.loadAllTasks()).single;
      expect(restored.folderId, 'folder-1');
      expect(restored.folderSortOrder, 2);
      expect(
        restored.policyTags,
        containsAll([
          MediaTaskPolicyTag.imageFormatFallback,
          MediaTaskPolicyTag.ineffectiveCompression,
        ]),
      );
    });

    test('task folder repository saves, orders, and deletes folders', () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = DriftTaskFolderRepository(database);
      final laterFolder = TaskFolder(
        id: 'folder-later',
        name: '后导入',
        mediaKind: MediaKind.video,
        sortOrder: 1,
        defaultConfig: MediaTaskConfig.initialVideo(),
        createdAt: 20,
        updatedAt: 20,
      );
      final earlierFolder = TaskFolder(
        id: 'folder-earlier',
        name: '先导入',
        mediaKind: MediaKind.image,
        sortOrder: 0,
        defaultConfig: MediaTaskConfig.initialImage(),
        createdAt: 10,
        updatedAt: 10,
      );

      await repository.saveFolder(laterFolder);
      await repository.saveFolder(earlierFolder);

      final folders = await repository.loadAllFolders();
      expect(folders.map((folder) => folder.id), [
        'folder-earlier',
        'folder-later',
      ]);
      expect(folders.first.defaultConfig.image, isNotNull);
      expect(folders.last.defaultConfig.video, isNotNull);

      await repository.deleteFolderById('folder-earlier');

      final remainingFolders = await repository.loadAllFolders();
      expect(remainingFolders.map((folder) => folder.id), ['folder-later']);
    });
  });
}

MediaTask mediaTask({
  String id = 'task-1',
  TaskStatus status = TaskStatus.pending,
  double progress = 0,
  int sortOrder = 0,
  String? outputPath,
  MediaAnalysisResult? analysisResult,
}) {
  return MediaTask(
    id: id,
    inputPath: '/videos/$id.mp4',
    fileName: '$id.mp4',
    mediaKind: MediaKind.video,
    purpose: TaskPurpose.compression,
    status: status,
    config: VideoTaskConfig.initial(),
    progress: progress,
    sortOrder: sortOrder,
    outputPath: outputPath,
    createdAt: 1,
    analysisResult: analysisResult,
  );
}

TaskRow taskRow({
  String id = 'task-1',
  String inputPath = '/videos/source.mp4',
  String fileName = 'source.mp4',
  String mediaKind = 'video',
  String? mediaConfigJson,
  int? outputFileSize,
  int? analysisImageWidth,
  int? analysisImageHeight,
  String? analysisImageCodec,
  String? analysisImagePixelFormat,
  int? analysisImageBitDepth,
  String status = 'pending',
  String? failureJson,
  String? errorMessage,
  String? analysisErrorMessage,
}) {
  return TaskRow(
    id: id,
    inputPath: inputPath,
    fileName: fileName,
    mediaKind: mediaKind,
    purpose: 'compression',
    status: status,
    progress: 0,
    sortOrder: 0,
    outputFileSize: outputFileSize,
    failureJson: failureJson,
    errorMessage: errorMessage,
    analysisErrorMessage: analysisErrorMessage,
    analysisDurationMs: 1000,
    analysisVideoWidth: 3840,
    analysisVideoHeight: 2160,
    analysisVideoCodec: 'hevc',
    analysisAudioCodec: 'aac',
    analysisVideoPixelFormat: 'p010le',
    analysisVideoBitDepth: 10,
    analysisColorRange: 'tv',
    analysisColorSpace: 'bt2020nc',
    analysisColorTransfer: 'smpte2084',
    analysisColorPrimaries: 'bt2020',
    analysisChromaLocation: 'left',
    analysisMasteringDisplayMetadata: 'red_x=34000/50000',
    analysisMasteringDisplayMaxLuminance: 1000,
    analysisMaxContentLightLevel: 1000,
    analysisMaxFrameAverageLightLevel: 400,
    analysisDolbyVisionProfile: 8,
    analysisDolbyVisionCompatibilityId: 1,
    analysisAverageFrameRate: '60000/1001',
    analysisRealFrameRate: '60000/1001',
    analysisSampleAspectRatio: '1:1',
    analysisDisplayAspectRatio: '16:9',
    analysisVideoRotationDegrees: -90,
    analysisFieldOrder: 'progressive',
    analysisAudioChannels: 2,
    analysisAudioSampleRate: 48000,
    analysisAudioChannelLayout: 'stereo',
    mediaConfigJson: mediaConfigJson,
    analysisImageWidth: analysisImageWidth,
    analysisImageHeight: analysisImageHeight,
    analysisImageCodec: analysisImageCodec,
    analysisImagePixelFormat: analysisImagePixelFormat,
    analysisImageBitDepth: analysisImageBitDepth,
    outputFormat: 'mp4',
    videoCodec: 'h264',
    encoderBackend: 'auto',
    resolutionPreset: 'original',
    outputDirectory: '',
    compressionCrf: 28,
    compressionMode: 'preset',
    outputFileName: '',
    createdAt: 1,
  );
}
