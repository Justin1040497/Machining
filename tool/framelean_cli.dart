import 'dart:io';

import 'package:args/args.dart';
import 'package:framelean/application/services/ffmpeg_planning/compression_advisor.dart';
import 'package:framelean/application/services/ffmpeg_planning/default_compression_advisor.dart';
import 'package:framelean/application/services/ffmpeg_planning/ffmpeg_command_builder.dart';
import 'package:framelean/application/services/execution/ffmpeg_process_observer.dart';
import 'package:framelean/domain/entities/app_settings.dart';
import 'package:framelean/domain/entities/media_task.dart';
import 'package:framelean/domain/enums/encoder_backend.dart';
import 'package:framelean/domain/enums/media_kind.dart';
import 'package:framelean/domain/enums/resolution_preset.dart';
import 'package:framelean/domain/enums/video_codec.dart';
import 'package:framelean/domain/value_objects/video_task_config.dart';
import 'package:framelean/infrastructure/services/execution/local_ffmpeg_process_observer.dart';
import 'package:framelean/infrastructure/services/execution/local_ffmpeg_process_starter.dart';
import 'package:framelean/infrastructure/services/ffmpeg_planning/default_ffmpeg_command_builder.dart';
import 'package:framelean/infrastructure/services/input_runtime/ffprobe_media_analyzer.dart';
import 'package:framelean/infrastructure/services/input_runtime/local_ffmpeg_locator.dart';
import 'package:path/path.dart' as path;

Future<void> main(List<String> args) async {
  final compressionAdvisor = DefaultCompressionAdvisor();
  final cli = FrameLeanCli(
    locator: LocalFfmpegLocator(),
    analyzer: FfprobeMediaAnalyzer(),
    compressionAdvisor: compressionAdvisor,
    commandBuilder: DefaultFfmpegCommandBuilder(
      compressionAdvisor: compressionAdvisor,
    ),
    processStarter: LocalFfmpegProcessStarter(),
    processObserver: LocalFfmpegProcessObserver(),
  );

  exitCode = await cli.run(args);
}

class FrameLeanCli {
  final LocalFfmpegLocator locator;
  final FfprobeMediaAnalyzer analyzer;
  final DefaultCompressionAdvisor compressionAdvisor;
  final DefaultFfmpegCommandBuilder commandBuilder;
  final LocalFfmpegProcessStarter processStarter;
  final LocalFfmpegProcessObserver processObserver;

  const FrameLeanCli({
    required this.locator,
    required this.analyzer,
    required this.compressionAdvisor,
    required this.commandBuilder,
    required this.processStarter,
    required this.processObserver,
  });

  Future<int> run(List<String> args) async {
    final parser = buildParser();
    if (args.isEmpty || args.first == '--help' || args.first == '-h') {
      printUsage();
      return 0;
    }

    late final ArgResults result;
    try {
      result = parser.parse(args);
    } on FormatException catch (error) {
      stderr.writeln(error.message);
      printUsage();
      return 64;
    }

    final command = result.command;
    if (command == null || command.name != 'compress') {
      stderr.writeln('不支持的命令: ${args.first}');
      printUsage();
      return 64;
    }

    if (command['help'] == true) {
      printUsage();
      return 0;
    }

    if (command.rest.length != 1) {
      stderr.writeln('compress 命令需要传入一个视频文件路径。');
      printUsage();
      return 64;
    }

    final options = CliCompressOptions(
      inputPath: command.rest.single,
      videoCodec: parseVideoCodecOrDefault(command['codec'] as String?),
      resolutionPreset: parseResolutionPreset(command['resolution'] as String),
    );

    return compress(options);
  }

  ArgParser buildParser() {
    final parser = ArgParser();
    final compressParser = ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false, help: '显示 compress 命令帮助。')
      ..addOption(
        'codec',
        abbr: 'c',
        allowed: ['source', 'h264', 'h265', 'hevc'],
        help: '目标视频编码。不传时使用 App 默认编码，初始为 H.264。',
      )
      ..addOption(
        'resolution',
        abbr: 'r',
        defaultsTo: 'original',
        allowed: ['original', '2160p', '1080p', '720p', '480p'],
        help: '目标分辨率。original 表示保持原始分辨率。',
      );

    parser.addCommand('compress', compressParser);
    return parser;
  }

  Future<int> compress(CliCompressOptions options) async {
    final inputPath = options.inputPath;
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      stderr.writeln('找不到输入文件: $inputPath');
      return 66;
    }

    stdout.writeln('FrameLean CLI');
    stdout.writeln('输入文件: ${path.absolute(inputPath)}');

    final runtime = await locator.resolve();
    final ffmpeg = runtime.ffmpeg;
    final ffprobe = runtime.ffprobe;
    if (ffmpeg == null || ffprobe == null) {
      stderr.writeln('无法找到可用的 ffmpeg / ffprobe。');
      stderr.writeln('请先安装 FFmpeg，或后续在 App 设置中指定自定义路径。');
      return 69;
    }

    stdout.writeln('ffmpeg: ${ffmpeg.path}');
    stdout.writeln('ffprobe: ${ffprobe.path}');

    MediaTask task;
    try {
      stdout.writeln('正在分析媒体信息...');
      final analysis = await analyzer.analyze(
        ffprobePath: ffprobe.path,
        inputPath: inputPath,
      );
      task = MediaTask.draft(
        inputPath: inputPath,
        fileName: path.basename(inputPath),
        mediaKind: MediaKind.video,
        sortOrder: 0,
        config: VideoTaskConfig.initial().copyWith(
          videoCodec: options.videoCodec,
          encoderBackend: EncoderBackend.auto,
          resolutionPreset: options.resolutionPreset,
        ),
      ).withAnalysisResult(analysis);
      stdout.writeln(formatAnalysis(task));
    } on Object catch (error) {
      stderr.writeln('FFprobe 分析失败: $error');
      return 65;
    }

    var allowExtremeCompression = false;
    final recommendation = compressionAdvisor.recommend(task);
    try {
      stdout.writeln(
        formatCompressionPreview(
          task: task,
          sourceSizeBytes: await inputFile.length(),
          recommendation: recommendation,
        ),
      );
    } on Object catch (error) {
      stderr.writeln('压缩预览生成失败: $error');
      return 65;
    }

    if (recommendation.shouldWarnUser) {
      stdout.writeln(recommendation.message);
      stdout.writeln('当前码率: ${formatBitrate(recommendation.bitrate)}');
      stdout.writeln(
        '低码率阈值: ${formatBitrate(recommendation.lowBitrateThreshold)}',
      );
      stdout.write('是否继续使用极限压缩策略？输入 y 继续，其他输入取消: ');
      final answer = stdin.readLineSync()?.trim().toLowerCase();
      if (answer != 'y' && answer != 'yes') {
        stdout.writeln('已取消本次压缩，未启动 FFmpeg。');
        return 0;
      }

      allowExtremeCompression = true;
    }

    late final FfmpegCommandPlan plan;
    try {
      plan = commandBuilder.build(
        task,
        allowExtremeCompression: allowExtremeCompression,
      );
    } on Object catch (error) {
      stderr.writeln('FFmpeg 命令构造失败: $error');
      return 65;
    }
    stdout.writeln('输出文件: ${path.absolute(plan.outputPath)}');
    stdout.writeln('命令说明: ${plan.logHint}');

    final logFile = await createLogFile(task);
    stdout.writeln('原始日志: ${logFile.path}');

    final runningTask = task.markRunning(outputPath: plan.outputPath);
    try {
      stdout.writeln('开始执行 FFmpeg...');
      final startedProcess = await processStarter.start(
        ffmpegPath: ffmpeg.path,
        args: plan.args,
        logFile: logFile,
      );

      var lastPrintedPercent = -1;
      final result = await processObserver.observe(
        startedProcess: startedProcess,
        task: runningTask,
        outputPath: plan.outputPath,
        onProgress: (progress) async {
          final percent = (progress * 100).floor();
          if (percent != lastPrintedPercent) {
            lastPrintedPercent = percent;
            stdout.write('\r进度: $percent%');
          }
        },
      );

      stdout.writeln();
      return printExecutionResult(result, plan.outputPath, logFile.path);
    } on Object catch (error) {
      stderr.writeln('FFmpeg 启动或执行失败: $error');
      stderr.writeln('原始日志: ${logFile.path}');
      return 70;
    }
  }

  void printUsage() {
    stdout.writeln('用法:');
    stdout.writeln(
      '  dart run tool/framelean_cli.dart compress <input-video> '
      '[--codec source|h264|h265|hevc] '
      '[--resolution original|2160p|1080p|720p|480p]',
    );
    stdout.writeln('');
    stdout.writeln('示例:');
    stdout.writeln(
      '  dart run tool/framelean_cli.dart compress ~/Movies/demo.mp4',
    );
    stdout.writeln(
      '  dart run tool/framelean_cli.dart compress ~/Movies/demo.mp4 '
      '--codec h265 --resolution 1080p',
    );
  }

  String formatAnalysis(MediaTask task) {
    final analysis = task.analysisResult;
    if (analysis == null) {
      return '媒体分析完成。';
    }

    final duration = analysis.durationMs == null
        ? '未知'
        : '${(analysis.durationMs! / 1000).toStringAsFixed(1)}s';
    final resolution =
        '${analysis.videoWidth ?? "?"}x${analysis.videoHeight ?? "?"}';
    final videoCodec = analysis.videoCodec ?? '未知';
    final audioCodec = analysis.audioCodec ?? '无音频或未知';

    return '媒体分析完成: 时长 $duration, 分辨率 $resolution, '
        '视频 $videoCodec, 音频 $audioCodec';
  }

  String formatCompressionPreview({
    required MediaTask task,
    required int sourceSizeBytes,
    required CompressionRecommendation recommendation,
  }) {
    final analysis = task.analysisResult;
    final sourceCodec = analysis?.videoCodec ?? '未知';
    final targetCodec = commandBuilder.resolveTargetVideoCodec(task);
    final sourceResolution = formatSourceResolution(task);
    final targetResolution = formatTargetResolution(task);

    return [
      '压缩预览:',
      '源视频编码: $sourceCodec',
      '目标视频编码: ${formatVideoCodec(targetCodec)}',
      '源视频大小: ${formatBytes(sourceSizeBytes)}',
      '源视频码率: ${formatBitrate(recommendation.bitrate)}',
      '原分辨率: $sourceResolution',
      '目标分辨率: $targetResolution',
      ...formatCompressionModePreview(recommendation),
    ].join('\n');
  }

  String formatVideoCodec(VideoCodec codec) {
    return switch (codec) {
      VideoCodec.source => '跟随源文件',
      VideoCodec.h264 => 'H.264',
      VideoCodec.hevc => 'H.265 / HEVC',
    };
  }

  List<String> formatCompressionModePreview(
    CompressionRecommendation recommendation,
  ) {
    if (recommendation.profile == CompressionProfile.normal) {
      return ['压缩模式: 普通质量压缩 CRF ${recommendation.crf}', '预计输出大小: CRF 模式无法准确预估'];
    }

    final modeText = recommendation.profile == CompressionProfile.targetSize
        ? '指定目标体积压缩'
        : '目标码率压缩';
    return [
      '压缩模式: $modeText',
      '预计输出大小: ${formatBytesNullable(recommendation.estimatedOutputSizeBytes)}',
      '目标总码率: ${formatBitrate(recommendation.targetTotalBitrate)}',
      '目标视频码率: ${formatBitrate(recommendation.targetVideoBitrate)}',
      '目标音频码率: ${formatBitrate(recommendation.targetAudioBitrate)}',
    ];
  }

  String formatSourceResolution(MediaTask task) {
    final analysis = task.analysisResult;
    final width = analysis?.videoWidth;
    final height = analysis?.videoHeight;
    if (width == null || height == null) {
      return '未知';
    }

    return '${width}x$height';
  }

  String formatTargetResolution(MediaTask task) {
    final analysis = task.analysisResult;
    final sourceWidth = analysis?.videoWidth;
    final sourceHeight = analysis?.videoHeight;
    final targetHeight = switch (task.config.resolutionPreset) {
      ResolutionPreset.original => null,
      ResolutionPreset.p2160 => 2160,
      ResolutionPreset.p1080 => 1080,
      ResolutionPreset.p720 => 720,
      ResolutionPreset.p480 => 480,
    };

    if (targetHeight == null) {
      return formatSourceResolution(task);
    }

    if (sourceWidth == null || sourceHeight == null || sourceHeight <= 0) {
      return '等比缩放到 ${targetHeight}p';
    }

    final targetWidth = makeEven(
      (sourceWidth * targetHeight / sourceHeight).round(),
    );
    return '${targetWidth}x$targetHeight';
  }

  int makeEven(int value) {
    if (value.isEven) {
      return value;
    }

    return value + 1;
  }

  Future<File> createLogFile(MediaTask task) async {
    final logsDirectory = Directory(
      path.join(Directory.systemTemp.path, 'framelean', 'cli-ffmpeg-logs'),
    );
    await logsDirectory.create(recursive: true);

    final safeFileName = task.fileName.replaceAll(
      RegExp(r'[^A-Za-z0-9._-]'),
      '_',
    );
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    return File(path.join(logsDirectory.path, '$timestamp-$safeFileName.log'));
  }

  Future<int> printExecutionResult(
    FfmpegProcessObservation result,
    String outputPath,
    String logFilePath,
  ) async {
    switch (result.status) {
      case FfmpegProcessObservationStatus.completed:
        final outputFile = File(outputPath);
        final sizeBytes = await outputFile.length();
        stdout.writeln('执行结果: completed');
        stdout.writeln('输出路径: ${path.absolute(outputPath)}');
        stdout.writeln('输出大小: ${formatBytes(sizeBytes)}');
        stdout.writeln('原始日志: $logFilePath');
        return 0;
      case FfmpegProcessObservationStatus.failed:
        stderr.writeln('执行结果: failed');
        stderr.writeln('错误信息: ${result.message ?? "未知错误"}');
        stderr.writeln('原始日志: $logFilePath');
        return 70;
    }
  }

  String formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;

    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex += 1;
    }

    return '${value.toStringAsFixed(unitIndex == 0 ? 0 : 2)} '
        '${units[unitIndex]}';
  }

  String formatBytesNullable(int? bytes) {
    if (bytes == null) {
      return '未知';
    }

    return formatBytes(bytes);
  }

  String formatBitrate(int? bitrate) {
    if (bitrate == null) {
      return '未知';
    }

    return '${(bitrate / 1000000).toStringAsFixed(2)} Mbps';
  }

  VideoCodec parseVideoCodecOrDefault(String? value) {
    if (value == null) {
      return AppSettings.initial().defaultOutputVideoCodec;
    }

    return switch (value) {
      'source' => VideoCodec.source,
      'h264' => VideoCodec.h264,
      'h265' => VideoCodec.hevc,
      'hevc' => VideoCodec.hevc,
      _ => throw FormatException('不支持的编码参数: $value'),
    };
  }

  ResolutionPreset parseResolutionPreset(String value) {
    return switch (value) {
      'original' => ResolutionPreset.original,
      '2160p' => ResolutionPreset.p2160,
      '1080p' => ResolutionPreset.p1080,
      '720p' => ResolutionPreset.p720,
      '480p' => ResolutionPreset.p480,
      _ => throw FormatException('不支持的分辨率参数: $value'),
    };
  }
}

class CliCompressOptions {
  final String inputPath;
  final VideoCodec videoCodec;
  final ResolutionPreset resolutionPreset;

  const CliCompressOptions({
    required this.inputPath,
    required this.videoCodec,
    required this.resolutionPreset,
  });
}
