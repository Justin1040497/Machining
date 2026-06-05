import 'package:framelean/application/services/ffmpeg_planning/compression_advisor.dart';
import 'package:framelean/application/services/ffmpeg_planning/default_compression_advisor.dart';
import 'package:framelean/application/services/ffmpeg_planning/ffmpeg_command_builder.dart';
import 'package:framelean/application/services/input_runtime/ffmpeg_encoder_capabilities.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/audio_codec.dart';
import 'package:framelean/domain/enums/image_codec.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/media_output_format.dart';
import 'package:framelean/domain/enums/output_format.dart';
import 'package:framelean/domain/enums/task_purpose.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/audio_processing_config.dart';
import 'package:framelean/domain/value_objects/image_processing_config.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_command_formatters.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_command_log_hint_builder.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_command_step_builder.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_encoder_resolver.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_output_path_builder.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_video_argument_builder.dart';

class DefaultFfmpegCommandBuilder implements FfmpegCommandBuilder {
  final CompressionAdvisor compressionAdvisor;
  final FfmpegOutputPathBuilder outputPathBuilder;
  final FfmpegEncoderResolver encoderResolver;
  final FfmpegVideoArgumentBuilder argumentBuilder;
  final FfmpegCommandStepBuilder stepBuilder;
  final FfmpegCommandLogHintBuilder logHintBuilder;

  DefaultFfmpegCommandBuilder({
    bool Function(String outputPath)? pathExists,
    CompressionAdvisor? compressionAdvisor,
    FfmpegOutputPathBuilder? outputPathBuilder,
    FfmpegEncoderResolver? encoderResolver,
    FfmpegVideoArgumentBuilder? argumentBuilder,
    FfmpegCommandStepBuilder? stepBuilder,
    FfmpegCommandLogHintBuilder? logHintBuilder,
  }) : compressionAdvisor = compressionAdvisor ?? DefaultCompressionAdvisor(),
       outputPathBuilder =
           outputPathBuilder ?? FfmpegOutputPathBuilder(pathExists: pathExists),
       encoderResolver = encoderResolver ?? const FfmpegEncoderResolver(),
       argumentBuilder = argumentBuilder ?? const FfmpegVideoArgumentBuilder(),
       stepBuilder =
           stepBuilder ??
           FfmpegCommandStepBuilder(
             argumentBuilder:
                 argumentBuilder ?? const FfmpegVideoArgumentBuilder(),
           ),
       logHintBuilder = logHintBuilder ?? const FfmpegCommandLogHintBuilder();

  @override
  FfmpegCommandPlan build(
    MediaTask task, {
    bool allowExtremeCompression = false,
    FfmpegEncoderCapabilities encoderCapabilities =
        FfmpegEncoderCapabilities.softwareOnly,
  }) {
    switch (task.mediaKind) {
      case MediaKind.video:
        return buildVideoCommandPlan(
          task,
          allowExtremeCompression: allowExtremeCompression,
          encoderCapabilities: encoderCapabilities,
        );
      case MediaKind.image:
        return buildImageCommandPlan(task);
      case MediaKind.audio:
        return buildAudioCommandPlan(task);
    }
  }

  FfmpegCommandPlan buildVideoCommandPlan(
    MediaTask task, {
    required bool allowExtremeCompression,
    required FfmpegEncoderCapabilities encoderCapabilities,
  }) {
    encoderResolver.ensureSupportedTask(task, encoderCapabilities);

    final outputPath = outputPathBuilder.buildOutputPath(task);
    final targetCodec = encoderResolver.resolveTargetVideoCodec(task);
    final recommendation = compressionAdvisor.recommend(
      task,
      allowExtremeCompression: allowExtremeCompression,
    );
    final videoEncoder = encoderResolver.resolveVideoEncoderForTask(
      task: task,
      targetCodec: targetCodec,
      backend: task.config.encoderBackend,
      encoderCapabilities: encoderCapabilities,
    );
    ensureCompressionConfirmed(task, recommendation);
    final steps = stepBuilder.buildCommandSteps(
      task: task,
      recommendation: recommendation,
      targetCodec: targetCodec,
      videoEncoder: videoEncoder,
      encoderCapabilities: encoderCapabilities,
      outputPath: outputPath,
    );
    final args = steps.last.args;

    return FfmpegCommandPlan(
      args: args,
      steps: steps,
      cleanupPathPrefixes: steps.length > 1
          ? [stepBuilder.passLogFilePrefix(outputPath)]
          : const [],
      outputPath: outputPath,
      logHint: logHintBuilder.buildLogHint(
        task,
        recommendation,
        targetCodec,
        videoEncoder,
      ),
    );
  }

  FfmpegCommandPlan buildImageCommandPlan(MediaTask task) {
    final config = task.config.image;
    if (config == null) {
      throw const FfmpegCommandBuildException('图片任务缺少图片配置');
    }

    final outputPath = outputPathBuilder.buildOutputPath(task);
    final args = <String>[
      '-hide_banner',
      '-y',
      '-i',
      task.inputPath,
      ...buildImageFilterArgs(config),
      ...buildImageCodecArgs(config),
      outputPath,
    ];
    final step = FfmpegCommandStep(
      args: args,
      label: '生成图片输出文件',
      outputPath: outputPath,
      progressMode: ProgressMode.step,
    );

    return FfmpegCommandPlan(
      args: args,
      steps: [step],
      outputPath: outputPath,
      logHint: '图片处理 ${config.outputFormat.name} 质量 ${config.imageQuality}',
    );
  }

  FfmpegCommandPlan buildAudioCommandPlan(MediaTask task) {
    final config = task.config.audio;
    if (config == null) {
      throw const FfmpegCommandBuildException('音频任务缺少音频配置');
    }

    final outputPath = outputPathBuilder.buildOutputPath(task);
    final args = <String>[
      '-hide_banner',
      '-y',
      '-i',
      task.inputPath,
      '-vn',
      ...buildAudioCodecArgs(config),
      '-progress',
      'pipe:1',
      outputPath,
    ];

    return FfmpegCommandPlan(
      args: args,
      outputPath: outputPath,
      logHint:
          '音频处理 ${config.outputFormat.name} ${effectiveAudioCodec(config).name}',
    );
  }

  FfmpegCommandPlan buildPreviewSegment(
    MediaTask task, {
    required double startSeconds,
    required double durationSeconds,
    required String outputPath,
    bool allowExtremeCompression = false,
    FfmpegEncoderCapabilities encoderCapabilities =
        FfmpegEncoderCapabilities.softwareOnly,
  }) {
    encoderResolver.ensureSupportedTask(task, encoderCapabilities);

    final targetCodec = encoderResolver.resolveTargetVideoCodec(task);
    final videoEncoder = encoderResolver.resolveVideoEncoderForTask(
      task: task,
      targetCodec: targetCodec,
      backend: task.config.encoderBackend,
      encoderCapabilities: encoderCapabilities,
    );
    final recommendation = compressionAdvisor.recommend(
      task,
      allowExtremeCompression: allowExtremeCompression,
    );
    ensureCompressionConfirmed(task, recommendation);
    final args = <String>[
      '-hide_banner',
      '-y',
      '-ss',
      FfmpegCommandFormatters.formatSeconds(startSeconds),
      '-t',
      FfmpegCommandFormatters.formatSeconds(durationSeconds),
      '-i',
      task.inputPath,
      ...argumentBuilder.buildOutputStreamSelectionArgs(task),
      ...argumentBuilder.buildPurposeArgs(task, recommendation, videoEncoder),
      ...argumentBuilder.buildVideoFilterArgs(task, videoEncoder),
      ...argumentBuilder.buildCommonOutputArgs(
        task,
        recommendation,
        targetCodec,
        videoEncoder,
        encoderCapabilities,
      ),
      outputPath,
    ];

    return FfmpegCommandPlan(
      args: args,
      outputPath: outputPath,
      logHint: logHintBuilder.buildLogHint(
        task,
        recommendation,
        targetCodec,
        videoEncoder,
      ),
    );
  }

  String extensionFor(OutputFormat outputFormat) {
    return outputPathBuilder.extensionFor(outputFormat);
  }

  List<String> buildImageFilterArgs(ImageProcessingConfig config) {
    final longEdge = switch (config.resizePreset) {
      ImageResizePreset.original => null,
      ImageResizePreset.longEdge3840 => 3840,
      ImageResizePreset.longEdge2560 => 2560,
      ImageResizePreset.longEdge1920 => 1920,
      ImageResizePreset.longEdge1280 => 1280,
      ImageResizePreset.longEdge720 => 720,
    };
    if (longEdge == null) {
      return const [];
    }

    return [
      '-vf',
      "scale='if(gt(iw,ih),min(iw,$longEdge),-2)':"
          "'if(gt(iw,ih),-2,min(ih,$longEdge))':flags=lanczos",
    ];
  }

  List<String> buildImageCodecArgs(ImageProcessingConfig config) {
    final codec = effectiveImageCodec(config);
    final metadataArgs = config.preserveMetadata
        ? const <String>[]
        : const ['-map_metadata', '-1'];

    switch (codec) {
      case ImageCodec.source:
        return ['-frames:v', '1', ...metadataArgs];
      case ImageCodec.jpeg:
        return [
          '-frames:v',
          '1',
          '-q:v',
          jpegQualityScale(config.imageQuality).toString(),
          ...metadataArgs,
        ];
      case ImageCodec.png:
        return ['-frames:v', '1', '-compression_level', '9', ...metadataArgs];
      case ImageCodec.webp:
        return [
          '-frames:v',
          '1',
          '-c:v',
          'libwebp',
          '-quality',
          config.imageQuality.toString(),
          ...metadataArgs,
        ];
    }
  }

  ImageCodec effectiveImageCodec(ImageProcessingConfig config) {
    if (config.imageCodec != ImageCodec.source) {
      return config.imageCodec;
    }

    return switch (config.outputFormat) {
      MediaOutputFormat.jpg => ImageCodec.jpeg,
      MediaOutputFormat.png => ImageCodec.png,
      MediaOutputFormat.webp => ImageCodec.webp,
      _ => ImageCodec.jpeg,
    };
  }

  int jpegQualityScale(int quality) {
    final normalized = quality.clamp(1, 100);
    final value = 31 - ((normalized - 1) * 29 / 99).round();
    if (value < 2) {
      return 2;
    }
    if (value > 31) {
      return 31;
    }
    return value;
  }

  List<String> buildAudioCodecArgs(AudioProcessingConfig config) {
    final args = <String>[
      '-c:a',
      audioEncoderName(effectiveAudioCodec(config)),
    ];
    final bitrate = audioBitrateValue(config.bitratePreset);
    if (bitrate != null) {
      args.addAll(['-b:a', bitrate]);
    }

    final sampleRate = audioSampleRateValue(config.sampleRate);
    if (sampleRate != null) {
      args.addAll(['-ar', sampleRate.toString()]);
    }

    final channels = audioChannelsValue(config.channels);
    if (channels != null) {
      args.addAll(['-ac', channels.toString()]);
    }

    return args;
  }

  AudioCodec effectiveAudioCodec(AudioProcessingConfig config) {
    if (config.audioCodec != AudioCodec.source) {
      return config.audioCodec;
    }

    return switch (config.outputFormat) {
      MediaOutputFormat.mp3 => AudioCodec.mp3,
      MediaOutputFormat.m4a || MediaOutputFormat.aac => AudioCodec.aac,
      MediaOutputFormat.flac => AudioCodec.flac,
      MediaOutputFormat.wav => AudioCodec.pcm,
      _ => AudioCodec.aac,
    };
  }

  String audioEncoderName(AudioCodec codec) {
    return switch (codec) {
      AudioCodec.source => 'copy',
      AudioCodec.aac => 'aac',
      AudioCodec.mp3 => 'libmp3lame',
      AudioCodec.opus => 'libopus',
      AudioCodec.flac => 'flac',
      AudioCodec.pcm => 'pcm_s16le',
    };
  }

  String? audioBitrateValue(AudioBitratePreset preset) {
    return switch (preset) {
      AudioBitratePreset.source => null,
      AudioBitratePreset.k320 => '320k',
      AudioBitratePreset.k192 => '192k',
      AudioBitratePreset.k128 => '128k',
      AudioBitratePreset.k96 => '96k',
      AudioBitratePreset.k64 => '64k',
    };
  }

  int? audioSampleRateValue(AudioSampleRatePreset preset) {
    return switch (preset) {
      AudioSampleRatePreset.source => null,
      AudioSampleRatePreset.hz48000 => 48000,
      AudioSampleRatePreset.hz44100 => 44100,
      AudioSampleRatePreset.hz32000 => 32000,
    };
  }

  int? audioChannelsValue(AudioChannelsPreset preset) {
    return switch (preset) {
      AudioChannelsPreset.source => null,
      AudioChannelsPreset.stereo => 2,
      AudioChannelsPreset.mono => 1,
    };
  }

  VideoCodec resolveTargetVideoCodec(MediaTask task) {
    return encoderResolver.resolveTargetVideoCodec(task);
  }

  String formatSeconds(double seconds) {
    return FfmpegCommandFormatters.formatSeconds(seconds);
  }

  void ensureCompressionConfirmed(
    MediaTask task,
    CompressionRecommendation recommendation,
  ) {
    if (task.purpose != TaskPurpose.compression) {
      return;
    }

    if (!recommendation.shouldWarnUser) {
      return;
    }

    throw CompressionConfirmationRequiredException(recommendation.message);
  }
}
