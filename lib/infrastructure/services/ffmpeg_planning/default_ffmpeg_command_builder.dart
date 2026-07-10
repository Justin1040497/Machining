import 'package:framelean/application/library.dart';
import 'package:framelean/domain/library.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_command_formatters.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_command_log_hint_builder.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_command_step_builder.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_encoder_resolver.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_output_path_builder.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/ffmpeg_video_argument_builder.dart';
import 'package:path/path.dart' as path;

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
        return buildImageCommandPlan(
          task,
          encoderCapabilities: encoderCapabilities,
        );
      case MediaKind.audio:
        return buildAudioCommandPlan(
          task,
          encoderCapabilities: encoderCapabilities,
        );
    }
  }

  FfmpegCommandPlan buildVideoCommandPlan(
    MediaTask task, {
    required bool allowExtremeCompression,
    required FfmpegEncoderCapabilities encoderCapabilities,
  }) {
    final preserveAlpha = argumentBuilder.shouldPreserveAlpha(task);
    ensureOutputFormatBelongsToKind(
      task.config.video?.outputFormat ?? MediaOutputFormat.mp4,
      MediaKind.video,
    );

    final outputPath = outputPathBuilder.buildOutputPath(task);
    final targetCodec = preserveAlpha
        ? VideoCodec.h264
        : encoderResolver.resolveTargetVideoCodec(task);
    if (!preserveAlpha &&
        !VideoOutputCompatibility.supports(
          task.config.outputFormat,
          targetCodec,
        )) {
      throw FfmpegCommandBuildException(
        '${task.config.outputFormat.name.toUpperCase()} 不支持 '
        '${targetCodec.name} 视频编码。',
      );
    }
    final streamCopy =
        !preserveAlpha &&
        stepBuilder.canStreamCopyConversion(task, targetCodec);
    if (!preserveAlpha && !streamCopy) {
      encoderResolver.ensureSupportedTask(task, encoderCapabilities);
    } else if (preserveAlpha &&
        !encoderCapabilities.encoderNames.contains('prores_ks')) {
      throw const FfmpegCommandBuildException(
        '当前 FFmpeg 不支持透明保留输出编码器: prores_ks。'
        '请在设置中指定带该编码器的 FFmpeg，或改用非透明素材。',
      );
    }
    final recommendation = compressionAdvisor.recommend(
      task,
      allowExtremeCompression: allowExtremeCompression,
    );
    final videoEncoder = preserveAlpha
        ? 'prores_ks'
        : streamCopy
        ? 'copy'
        : encoderResolver.resolveVideoEncoderForTask(
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

  FfmpegCommandPlan buildImageCommandPlan(
    MediaTask task, {
    FfmpegEncoderCapabilities encoderCapabilities =
        FfmpegEncoderCapabilities.softwareOnly,
  }) {
    final config = task.config.image;
    if (config == null) {
      throw const FfmpegCommandBuildException('图片任务缺少图片配置');
    }
    ensureOutputFormatBelongsToKind(config.outputFormat, MediaKind.image);

    final isConversion = task.purpose == TaskPurpose.conversion;
    final primaryOutputFormat = imagePrimaryOutputFormatFor(task, config);
    final primaryConfig = config.copyWith(
      outputFormat: primaryOutputFormat,
      resizePreset: isConversion
          ? ImageResizePreset.original
          : config.resizePreset,
      imageQuality: isConversion ? 100 : config.imageQuality,
      losslessCompression: isConversion
          ? primaryOutputFormat == MediaOutputFormat.webp
          : config.losslessCompression,
    );
    final primaryTask = task.copyWith(
      config: task.config.copyWith(image: primaryConfig),
    );

    final outputPath = outputPathBuilder.buildOutputPath(primaryTask);
    final fallbackFormat = task.purpose == TaskPurpose.compression
        ? imageFallbackFormatFor(
            primaryTask,
            primaryConfig,
            encoderCapabilities,
          )
        : null;
    final steps = <FfmpegCommandStep>[
      buildImageCommandStep(
        task: primaryTask,
        config: primaryConfig,
        outputPath: outputPath,
        encoderCapabilities: encoderCapabilities,
        label: '按当前图片格式生成输出文件',
        completionPolicy: task.purpose == TaskPurpose.compression
            ? (fallbackFormat == null
                  ? FfmpegStepCompletionPolicy.failIfOutputNotSmallerThanSource
                  : FfmpegStepCompletionPolicy
                        .completeIfOutputSmallerThanSource)
            : FfmpegStepCompletionPolicy.alwaysContinue,
      ),
    ];

    if (fallbackFormat != null) {
      final fallbackConfig = primaryConfig.copyWith(
        outputFormat: fallbackFormat,
        keepOriginalOutputFormat: false,
      );
      final fallbackTask = primaryTask.copyWith(
        config: task.config.copyWith(image: fallbackConfig),
      );
      steps.add(
        buildImageCommandStep(
          task: fallbackTask,
          config: fallbackConfig,
          outputPath: outputPathBuilder.buildOutputPath(fallbackTask),
          encoderCapabilities: encoderCapabilities,
          label: '改用 ${fallbackFormat.name.toUpperCase()} 再次压缩图片',
          completionPolicy:
              FfmpegStepCompletionPolicy.failIfOutputNotSmallerThanSource,
          policyTagsOnStart: const {MediaTaskPolicyTag.imageFormatFallback},
        ),
      );
    }
    final args = steps.last.args;

    return FfmpegCommandPlan(
      args: args,
      steps: steps,
      outputPath: outputPath,
      logHint:
          '图片处理 ${primaryConfig.outputFormat.name} '
          '${primaryConfig.losslessCompression ? '无损压缩' : '质量 ${primaryConfig.imageQuality}'}',
    );
  }

  FfmpegCommandStep buildImageCommandStep({
    required MediaTask task,
    required ImageProcessingConfig config,
    required String outputPath,
    required FfmpegEncoderCapabilities encoderCapabilities,
    required String label,
    required FfmpegStepCompletionPolicy completionPolicy,
    Set<MediaTaskPolicyTag> policyTagsOnStart = const {},
  }) {
    final args = <String>[
      '-hide_banner',
      '-y',
      '-i',
      task.inputPath,
      ...buildImageFilterArgs(config),
      ...buildImageOutputArgs(config, encoderCapabilities),
      ...argumentBuilder.buildThreadArgs(task),
      outputPath,
    ];

    return FfmpegCommandStep(
      args: args,
      label: label,
      outputPath: outputPath,
      progressMode: ProgressMode.step,
      completionPolicy: completionPolicy,
      policyTagsOnStart: policyTagsOnStart,
    );
  }

  FfmpegCommandPlan buildAudioCommandPlan(
    MediaTask task, {
    FfmpegEncoderCapabilities encoderCapabilities =
        FfmpegEncoderCapabilities.softwareOnly,
  }) {
    final config = task.config.audio;
    if (config == null) {
      throw const FfmpegCommandBuildException('音频任务缺少音频配置');
    }
    ensureOutputFormatBelongsToKind(config.outputFormat, MediaKind.audio);

    final isConversion = task.purpose == TaskPurpose.conversion;
    final effectiveConfig = isConversion
        ? config.copyWith(
            bitratePreset: _conversionAudioBitrate(config.outputFormat),
            sampleRate: AudioSampleRatePreset.source,
            channels: AudioChannelsPreset.source,
          )
        : config;
    final outputPath = outputPathBuilder.buildOutputPath(task);
    final args = <String>[
      '-hide_banner',
      '-y',
      '-i',
      task.inputPath,
      '-vn',
      ...buildAudioOutputArgs(
        effectiveConfig,
        encoderCapabilities,
        preserveQuality: isConversion,
      ),
      ...buildAudioMetadataArgs(effectiveConfig),
      ...argumentBuilder.buildThreadArgs(task),
      '-progress',
      'pipe:1',
      outputPath,
    ];

    return FfmpegCommandPlan(
      args: args,
      steps: [
        FfmpegCommandStep(
          args: args,
          label: isConversion ? '转换音频格式' : '压缩音频',
          outputPath: outputPath,
          completionPolicy: isConversion
              ? FfmpegStepCompletionPolicy.alwaysContinue
              : FfmpegStepCompletionPolicy.failIfOutputNotSmallerThanSource,
        ),
      ],
      outputPath: outputPath,
      logHint: '音频处理 ${effectiveConfig.outputFormat.name}',
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
      ...argumentBuilder.buildThreadArgs(task),
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

  List<String> buildImageOutputArgs(
    ImageProcessingConfig config,
    FfmpegEncoderCapabilities encoderCapabilities,
  ) {
    final metadataArgs = config.preserveMetadata
        ? const <String>[]
        : const ['-map_metadata', '-1'];

    switch (config.outputFormat) {
      case MediaOutputFormat.jpg:
        ensureLosslessImageFormatSupported(config);
        return [
          '-frames:v',
          '1',
          '-q:v',
          jpegQualityScale(config.imageQuality).toString(),
          ...metadataArgs,
        ];
      case MediaOutputFormat.png:
        return ['-frames:v', '1', '-compression_level', '9', ...metadataArgs];
      case MediaOutputFormat.webp:
        if (!encoderCapabilities.supportsImageEncoder('libwebp')) {
          throw const FfmpegCommandBuildException(
            '当前 FFmpeg 不支持 WebP 输出编码器: libwebp。'
            '请在设置中指定带该编码器的 FFmpeg，或改选其他图片输出格式。',
          );
        }
        return [
          '-frames:v',
          '1',
          '-c:v',
          'libwebp',
          if (config.losslessCompression) ...[
            '-lossless',
            '1',
            '-compression_level',
            '6',
            '-quality',
            '100',
          ] else ...[
            '-quality',
            config.imageQuality.toString(),
          ],
          ...metadataArgs,
        ];
      case MediaOutputFormat.bmp:
        ensureLosslessImageFormatSupported(config);
        return ['-frames:v', '1', '-c:v', 'bmp', ...metadataArgs];
      case MediaOutputFormat.tiff:
        return [
          '-frames:v',
          '1',
          '-c:v',
          'tiff',
          if (config.losslessCompression) ...['-compression_algo', 'deflate'],
          ...metadataArgs,
        ];
      case MediaOutputFormat.gif:
        ensureLosslessImageFormatSupported(config);
        return ['-frames:v', '1', '-c:v', 'gif', ...metadataArgs];
      case MediaOutputFormat.mp4:
      case MediaOutputFormat.mov:
      case MediaOutputFormat.mkv:
      case MediaOutputFormat.webm:
      case MediaOutputFormat.avi:
      case MediaOutputFormat.mp3:
      case MediaOutputFormat.m4a:
      case MediaOutputFormat.aac:
      case MediaOutputFormat.wav:
      case MediaOutputFormat.flac:
      case MediaOutputFormat.aiff:
      case MediaOutputFormat.wma:
      case MediaOutputFormat.opus:
      case MediaOutputFormat.oggOpus:
        throw FfmpegCommandBuildException(
          '图片任务不支持输出 ${config.outputFormat.name}',
        );
    }
  }

  MediaOutputFormat? imageFallbackFormatFor(
    MediaTask task,
    ImageProcessingConfig config,
    FfmpegEncoderCapabilities encoderCapabilities,
  ) {
    if (!config.keepOriginalOutputFormat) {
      return null;
    }

    if (config.losslessCompression) {
      if (config.outputFormat != MediaOutputFormat.webp &&
          encoderCapabilities.supportsImageEncoder('libwebp')) {
        return MediaOutputFormat.webp;
      }
      return null;
    }

    final hasAlpha = imageHasAlpha(task);
    if (config.outputFormat != MediaOutputFormat.webp &&
        encoderCapabilities.supportsImageEncoder('libwebp')) {
      return MediaOutputFormat.webp;
    }

    if (!hasAlpha && config.outputFormat != MediaOutputFormat.jpg) {
      return MediaOutputFormat.jpg;
    }

    return null;
  }

  MediaOutputFormat imagePrimaryOutputFormatFor(
    MediaTask task,
    ImageProcessingConfig config,
  ) {
    final format =
        task.purpose == TaskPurpose.conversion ||
            !config.keepOriginalOutputFormat
        ? config.outputFormat
        : imageFormatFromCodec(task.analysisResult?.imageCodec) ??
              imageFormatFromExtension(path.extension(task.fileName)) ??
              imageFormatFromExtension(path.extension(task.inputPath)) ??
              config.outputFormat;

    if (config.losslessCompression &&
        !supportsLosslessImageCompression(format)) {
      return MediaOutputFormat.webp;
    }
    return format;
  }

  void ensureLosslessImageFormatSupported(ImageProcessingConfig config) {
    if (config.losslessCompression &&
        !supportsLosslessImageCompression(config.outputFormat)) {
      throw FfmpegCommandBuildException(
        '${config.outputFormat.name.toUpperCase()} 不支持无损图片压缩，'
        '请改用 PNG、WebP 或 TIFF。',
      );
    }
  }

  MediaOutputFormat? imageFormatFromCodec(String? codec) {
    final normalized = codec?.trim().toLowerCase();
    return switch (normalized) {
      'jpeg' || 'mjpeg' || 'jpg' => MediaOutputFormat.jpg,
      'png' => MediaOutputFormat.png,
      'webp' => MediaOutputFormat.webp,
      'bmp' => MediaOutputFormat.bmp,
      'tiff' || 'tif' => MediaOutputFormat.tiff,
      'gif' => MediaOutputFormat.gif,
      _ => null,
    };
  }

  MediaOutputFormat? imageFormatFromExtension(String extension) {
    return switch (extension.trim().toLowerCase()) {
      '.jpeg' || '.jpg' => MediaOutputFormat.jpg,
      '.png' => MediaOutputFormat.png,
      '.webp' => MediaOutputFormat.webp,
      '.bmp' => MediaOutputFormat.bmp,
      '.tiff' || '.tif' => MediaOutputFormat.tiff,
      '.gif' => MediaOutputFormat.gif,
      _ => null,
    };
  }

  bool imageHasAlpha(MediaTask task) {
    final pixelFormat = task.analysisResult?.imagePixelFormat
        ?.trim()
        .toLowerCase();
    if (pixelFormat == null || pixelFormat.isEmpty) {
      return task.config.image?.outputFormat == MediaOutputFormat.png ||
          task.config.image?.outputFormat == MediaOutputFormat.webp;
    }

    return pixelFormat.startsWith('yuva') ||
        pixelFormat == 'rgba' ||
        pixelFormat == 'bgra' ||
        pixelFormat == 'argb' ||
        pixelFormat == 'abgr' ||
        pixelFormat.startsWith('gbrap');
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

  List<String> buildAudioOutputArgs(
    AudioProcessingConfig config,
    FfmpegEncoderCapabilities encoderCapabilities, {
    bool preserveQuality = false,
  }) {
    final encoderName = audioEncoderName(
      config.outputFormat,
      preserveQuality: preserveQuality,
    );
    if (!encoderCapabilities.supportsAudioEncoder(encoderName)) {
      throw FfmpegCommandBuildException(
        '当前 FFmpeg 不支持 ${config.outputFormat.name.toUpperCase()} '
        '输出编码器: $encoderName。请在设置中指定带该编码器的 FFmpeg，'
        '或改选其他音频输出格式。',
      );
    }

    final args = <String>['-c:a', encoderName];
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

  List<String> buildAudioMetadataArgs(AudioProcessingConfig config) {
    return config.preserveMetadata ? const [] : const ['-map_metadata', '-1'];
  }

  String audioEncoderName(
    MediaOutputFormat outputFormat, {
    bool preserveQuality = false,
  }) {
    return switch (outputFormat) {
      MediaOutputFormat.mp3 => 'libmp3lame',
      MediaOutputFormat.m4a || MediaOutputFormat.aac => 'aac',
      MediaOutputFormat.opus || MediaOutputFormat.oggOpus => 'libopus',
      MediaOutputFormat.wav => preserveQuality ? 'pcm_s24le' : 'pcm_s16le',
      MediaOutputFormat.flac => 'flac',
      MediaOutputFormat.aiff => preserveQuality ? 'pcm_s24be' : 'pcm_s16be',
      MediaOutputFormat.wma => 'wmav2',
      MediaOutputFormat.mp4 ||
      MediaOutputFormat.mov ||
      MediaOutputFormat.mkv ||
      MediaOutputFormat.webm ||
      MediaOutputFormat.avi ||
      MediaOutputFormat.jpg ||
      MediaOutputFormat.png ||
      MediaOutputFormat.webp ||
      MediaOutputFormat.bmp ||
      MediaOutputFormat.tiff ||
      MediaOutputFormat.gif => throw FfmpegCommandBuildException(
        '音频任务不支持输出 ${outputFormat.name}',
      ),
    };
  }

  AudioBitratePreset _conversionAudioBitrate(MediaOutputFormat format) {
    return switch (format) {
      MediaOutputFormat.mp3 ||
      MediaOutputFormat.m4a ||
      MediaOutputFormat.aac ||
      MediaOutputFormat.wma ||
      MediaOutputFormat.opus ||
      MediaOutputFormat.oggOpus => AudioBitratePreset.k320,
      MediaOutputFormat.wav ||
      MediaOutputFormat.flac ||
      MediaOutputFormat.aiff => AudioBitratePreset.source,
      _ => AudioBitratePreset.source,
    };
  }

  void ensureOutputFormatBelongsToKind(
    MediaOutputFormat outputFormat,
    MediaKind mediaKind,
  ) {
    if (MediaOutputFormat.formatsFor(mediaKind).contains(outputFormat)) {
      return;
    }

    throw FfmpegCommandBuildException(
      '${mediaKind.name} 任务不支持输出 ${outputFormat.name}',
    );
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
