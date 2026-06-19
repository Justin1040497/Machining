import 'package:framelean/application/services/ffmpeg_planning/ffmpeg_command_builder.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/media_task_policy_tag.dart';

class OutputPreflightResult {
  const OutputPreflightResult({required this.plan, this.policyTags = const {}});

  final FfmpegCommandPlan plan;
  final Set<MediaTaskPolicyTag> policyTags;
}

abstract class OutputPreflightService {
  Future<OutputPreflightResult> prepare({
    required MediaTask task,
    required FfmpegCommandPlan plan,
  });
}

class NoopOutputPreflightService implements OutputPreflightService {
  const NoopOutputPreflightService();

  @override
  Future<OutputPreflightResult> prepare({
    required MediaTask task,
    required FfmpegCommandPlan plan,
  }) async {
    return OutputPreflightResult(plan: plan);
  }
}
