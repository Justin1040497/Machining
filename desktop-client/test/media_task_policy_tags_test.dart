import 'package:flutter_test/flutter_test.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/media_task_policy_tag.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/task_status.dart';
import 'package:framelean/domain/value_objects/media_analysis_result.dart';
import 'package:framelean/domain/value_objects/video_task_config.dart';

void main() {
  group('MediaTask policy tags', () {
    test('retry clears execution tags but keeps analysis tags', () {
      final retryTask = task(
        policyTags: const {
          MediaTaskPolicyTag.transparentPreserve,
          MediaTaskPolicyTag.outputRenamed,
          MediaTaskPolicyTag.imageFormatFallback,
          MediaTaskPolicyTag.ineffectiveCompression,
        },
      ).markPendingForRetry();

      expect(
        retryTask.policyTags,
        contains(MediaTaskPolicyTag.transparentPreserve),
      );
      expect(
        retryTask.policyTags,
        isNot(contains(MediaTaskPolicyTag.outputRenamed)),
      );
      expect(
        retryTask.policyTags,
        isNot(contains(MediaTaskPolicyTag.imageFormatFallback)),
      );
      expect(
        retryTask.policyTags,
        isNot(contains(MediaTaskPolicyTag.ineffectiveCompression)),
      );
    });

    test('analysis result refreshes transparent preserve tag', () {
      final nonTransparentTask = task(
        policyTags: const {MediaTaskPolicyTag.transparentPreserve},
      ).withAnalysisResult(MediaAnalysisResult(videoPixelFormat: 'yuv420p'));

      expect(
        nonTransparentTask.policyTags,
        isNot(contains(MediaTaskPolicyTag.transparentPreserve)),
      );

      final transparentTask = nonTransparentTask.withAnalysisResult(
        MediaAnalysisResult(videoPixelFormat: 'yuva444p10le'),
      );

      expect(
        transparentTask.policyTags,
        contains(MediaTaskPolicyTag.transparentPreserve),
      );
    });

    test('replacing source clears stale policy tags', () {
      final replacedTask =
          task(
            policyTags: const {
              MediaTaskPolicyTag.transparentPreserve,
              MediaTaskPolicyTag.outputDirectoryCreated,
            },
          ).replaceInputFile(
            newInputPath: '/videos/replacement.mp4',
            newFileName: 'replacement.mp4',
            newMediaKind: MediaKind.video,
          );

      expect(replacedTask.policyTags, isEmpty);
    });
  });
}

MediaTask task({Set<MediaTaskPolicyTag> policyTags = const {}}) {
  return MediaTask(
    id: 'task-1',
    inputPath: '/videos/source.mov',
    fileName: 'source.mov',
    mediaKind: MediaKind.video,
    purpose: TaskPurpose.compression,
    status: TaskStatus.failed,
    config: VideoTaskConfig.initial(),
    progress: 0,
    sortOrder: 0,
    createdAt: 1,
    policyTags: policyTags,
  );
}
