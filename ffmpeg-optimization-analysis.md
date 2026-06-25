# FrameLean FFmpeg / FFprobe 使用与压缩参数优化分析

> 分析范围：ffprobe 媒体分析、ffmpeg 命令构建、压缩参数策略、进程生命周期管理、并发资源调度。
> 分析时间：2026-06-24

---

## 一、执行摘要

整体架构相当成熟：命令构建、编码器解析、压缩策略、资源调度分层清晰，HDR/Alpha/色彩元数据处理细致，对硬件编码器（VideoToolbox/NVENC/QSV/AMF）和多 pass 目标体积压缩都有覆盖。测试覆盖面也较广。

但在**进程健壮性**和**性能细节**上存在若干可优化点，主要集中在三类：

1. **进程生命周期存在泄漏/挂死风险**（ffprobe 超时后僵尸进程、ffmpeg 无 stall 检测）—— 会偶发卡死，影响稳定性。
2. **压缩参数存在可调优空间**（preset 固定 slow、two-pass+CRF 逻辑分支、硬件 scale 未利用）—— 影响速度。
3. **进度/资源监控存在精度问题**（progress 字段歧义、VFR 倒退、Windows 内存检测缺失）—— 影响体验。

按优先级分级如下：

| 级别 | 问题 | 位置 | 影响 |
|------|------|------|------|
| **P0** | ffprobe 超时后进程未 kill，造成僵尸进程 | ffprobe_media_analyzer.dart:24-29 | 资源泄漏，长期运行内存上涨 |
| **P0** | ffmpeg 缺少"无进度超时"(stall detection) | local_ffmpeg_process_observer.dart | 进程挂死，任务永久卡在 running |
| **P1** | two-pass 在 CRF 模式下无意义地跑了 2 pass | ffmpeg_command_step_builder.dart:236-245 | 多耗 1x 编码时间 |
| **P1** | 码率上限表在 advisor 与 estimator 中重复 | default_compression_advisor.dart:254 / compression_estimator.dart:232 | 维护易不一致 |
| **P1** | progress 用 out_time_ms 字段（歧义命名） | local_ffmpeg_process_observer.dart:150 | 可读性差，未来兼容风险 |
| **P1** | 预览帧生成串行执行 3N 次 ffmpeg | local_preview_frame_generator.dart:126 | 预览慢 |
| **P2** | preset 固定 slow，无自适应 | default_compression_advisor.dart:10 | 速度慢于 medium 但质量优先 |
| **P2** | 硬件编码仍走 CPU lanczos scale | ffmpeg_video_argument_builder.dart:453 | 硬件编码场景 CPU 瓶颈 |
| **P2** | Windows 内存检测缺失 | local_execution_resource_guard.dart:121 | Win 并发判断不准 |
| **P2** | 缺少 -stats_period，进度粒度粗 | 全局 progress 输出 | 短视频进度跳跃 |
| **P2** | VFR/重滤镜场景 progress 可能倒退 | local_ffmpeg_process_observer.dart:157 | 进度回退体验差 |

---

## 二、P0 问题详解

### P0-1：ffprobe 超时后僵尸进程

**位置**：`lib/infrastructure/services/input_runtime/ffprobe_media_analyzer.dart:24-29`

```dart
final result = await Process.run(
  ffprobePath,
  buildArguments(inputPath),
  stdoutEncoding: utf8,
  stderrEncoding: utf8,
).timeout(timeout);   // ← 问题在这
```

**问题**：Dart 的 `.timeout()` 只是取消对 Future 的等待，**不会终止底层进程**。如果 ffprobe 卡住（损坏文件、网络挂载盘、加密容器），超时后调用方收到 TimeoutException，但 ffprobe 子进程仍在后台运行，持续占用 CPU/内存。长期运行（批量分析）会累积大量僵尸进程。

**影响**：批量导入时偶发卡顿、内存上涨，严重时触发 OOM。

**建议**：改用 `Process.start` + 手动 kill，确保超时时进程被真正终止：

```dart
Future<MediaAnalysisResult> analyze({
  required String ffprobePath,
  required String inputPath,
}) async {
  final file = File(inputPath);
  if (!await file.exists()) {
    throw StateError('源文件不存在: $inputPath');
  }

  final process = await Process.start(
    ffprobePath,
    buildArguments(inputPath),
  );
  final stdoutBuffer = StringBuffer();
  final stderrBuffer = StringBuffer();
  final stdoutSub = process.stdout
      .transform(utf8.decoder)
      .listen(stdoutBuffer.write);
  final stderrSub = process.stderr
      .transform(utf8.decoder)
      .listen(stderrBuffer.write);

  try {
    final exitCode = await process.exitCode.timeout(timeout);
    await stdoutSub.cancel();
    await stderrSub.cancel();

    if (exitCode != 0) {
      throw StateError('FFprobe 分析失败: $stderrBuffer');
    }
    final json = jsonDecode(stdoutBuffer.toString());
    if (json is! Map<String, dynamic>) {
      throw StateError('FFprobe 输出格式无效');
    }
    final fileSize = await file.length();
    return parseResult(json, fileSize: fileSize);
  } on TimeoutException {
    // 关键：确保进程被杀掉
    process.kill(ProcessSignal.sigkill);
    await stdoutSub.cancel();
    await stderrSub.cancel();
    throw TimeoutException('FFprobe 分析超时', timeout);
  }
}
```

---

### P0-2：FFmpeg 缺少无进度超时（stall detection）

**位置**：`lib/infrastructure/services/execution/local_ffmpeg_process_observer.dart`

**问题**：observer 监听 `process.exitCode` 和 stdout/stderr 流。如果 FFmpeg 进程既不退出、也不输出 progress（例如：读取网络挂载文件卡 IO、硬件编码器死锁、滤镜链死循环），`exitCode` 永远不完成，任务会**永久卡在 running 状态**，占用执行位，阻塞队列。

当前唯一的保护是 `_startOutputMonitor`（检测临时输出文件被删除），但这只覆盖"输出文件消失"这一种情况，不覆盖"进程挂死但输出文件还在"。

**影响**：偶发的任务永久卡死，用户必须手动取消。在连续队列模式下，一个卡死任务可能阻塞整个队列。

**建议**：在 observer 中增加"最后进度时间"追踪 + 超时熔断：

```dart
Future<FfmpegProcessObservation> observe({
  required StartedFfmpegProcess startedProcess,
  required MediaTask task,
  required String? outputPath,
  ProgressMode progressMode = ProgressMode.timed,
  required Future<void> Function(double progress) onProgress,
  Duration stallTimeout = const Duration(minutes: 5),
}) async {
  // ... 原有逻辑 ...
  DateTime lastProgressAt = DateTime.now();
  Timer? stallDetector;

  // 在 observeStdout 的 onProgress 回调里更新 lastProgressAt
  // 并启动一个定时器检测：
  stallDetector = Timer.periodic(
    const Duration(seconds: 30),
    (timer) {
      if (DateTime.now().difference(lastProgressAt) > stallTimeout) {
        timer.cancel();
        // 熔断：kill 进程，返回失败
        startedProcess.process.kill(ProcessSignal.sigterm);
        // 注入失败结果
      }
    },
  );
  // ... 完成后 stallDetector.cancel();
}
```

> 注意：stallTimeout 应该对重滤镜场景（HDR tonemap、zscale）适当放宽，避免误杀正常的慢速编码。

---

## 三、P1 问题详解

### P1-1：two-pass 在 CRF 模式下无意义

**位置**：`lib/infrastructure/services/ffmpeg_planning/ffmpeg_command_step_builder.dart:230-264`

```dart
List<String> buildTwoPassVideoArgs(...) {
  final targetVideoBitrate = recommendation.targetVideoBitrate;
  if (targetVideoBitrate == null) {
    return [
      '-c:v', videoEncoder,
      '-preset', recommendation.preset,
      '-crf', recommendation.crf.toString(),  // ← CRF 模式跑 two-pass
    ];
  }
  // ... 正常的 -b:v + -pass 逻辑
}
```

**问题**：CRF 是单 pass 质量模式，two-pass 的价值在于精确命中目标码率/体积。当 `targetVideoBitrate == null`（即走 CRF 而非目标码率）时，跑 two-pass 纯属浪费——第一 pass `-an -f null` 白跑一遍，耗时翻倍，结果和单 pass CRF 完全一样。

**触发条件**：`shouldUseTwoPassTargetSize` 返回 true（targetSize 模式 + 非 prores/mjpeg/硬件）但 `buildTargetSizeRecommendation` 因 durationMs 缺失返回了 null，退回到普通 CRF 推荐，却仍进了 two-pass 分支。

**建议**：在 `shouldUseTwoPassTargetSize` 中增加码率前置检查，或在 `buildTwoPassTargetSizeSteps` 开头判断：

```dart
bool shouldUseTwoPassTargetSize({...}) {
  // ... 原有条件 ...
  // 只有有明确目标码率时 two-pass 才有意义
  return task.purpose == TaskPurpose.compression &&
      recommendation.profile == CompressionProfile.targetSize &&
      recommendation.targetVideoBitrate != null &&  // ← 新增
      videoEncoder != 'prores_ks' &&
      videoEncoder != 'mjpeg' &&
      !FfmpegEncoderCapabilities.softwareOnly.isHardwareEncoder(videoEncoder);
}
```

---

### P1-2：码率上限表重复维护

**位置**：
- `default_compression_advisor.dart:254-305` `normalTargetVideoBitrateCeiling`
- `compression_estimator.dart:232-284` `videoBitrateCeiling`

两处有几乎一样的"分辨率 × preset → 码率上限"表（2160/1080/720/480 × clear/balanced/chat/compact）。任何一处改了，另一处容易漏改，导致"压缩策略"和"体积估算"不一致——用户看到的预估体积和实际产出偏差变大。

**建议**：抽出一个共享常量表，例如 `lib/domain/entities/video_bitrate_ceiling.dart`：

```dart
abstract final class VideoBitrateCeilings {
  static int h264Ceiling({
    required SmartCompressionPreset preset,
    required int height,
  }) {
    final h = height < 720 ? 480 : height < 1080 ? 720 : height < 2160 ? 1080 : 2160;
    return switch ((preset, h)) {
      (SmartCompressionPreset.clear, 2160) => 28000000,
      (SmartCompressionPreset.clear, 1080) => 8000000,
      // ...
      _ => 2000000,
    };
  }

  static int withCodecFactor(int h264Ceiling, VideoCodec codec) {
    final factor = switch (codec) {
      VideoCodec.hevc => 0.72,
      VideoCodec.vp9 => 0.68,
      VideoCodec.av1 => 0.55,
      _ => 1.0,
    };
    return (h264Ceiling * factor).round();
  }
}
```

让 advisor 和 estimator 都引用它。

---

### P1-3：progress 字段歧义

**位置**：`local_ffmpeg_process_observer.dart:148-155`

```dart
int? parseOutTimeMicroseconds(String line) {
  if (!trimmedLine.startsWith('out_time_ms=')) {  // ← 字段名带 ms
    return null;
  }
  return int.tryParse(trimmedLine.substring('out_time_ms='.length));
}
```

**问题**：FFmpeg 的 `out_time_ms` 是已知的历史命名陷阱——它返回的其实是**微秒**（μs），不是毫秒。函数命名 `parseOutTimeMicroseconds` 是对的，但读 `out_time_ms` 会让后人误以为是毫秒而引入 bug。

**建议**：优先读取 `out_time_us`（FFmpeg 5.0+ 明确的微秒字段），回退到 `out_time_ms`：

```dart
int? parseOutTimeMicroseconds(String line) {
  final trimmed = line.trim();
  if (trimmed.startsWith('out_time_us=')) {
    return int.tryParse(trimmed.substring('out_time_us='.length));
  }
  // 兼容旧版 FFmpeg（out_time_ms 实际返回微秒）
  if (trimmed.startsWith('out_time_ms=')) {
    return int.tryParse(trimmed.substring('out_time_ms='.length));
  }
  return null;
}
```

---

### P1-4：预览帧生成串行

**位置**：`local_preview_frame_generator.dart:126-186`

每张预览帧要跑 3 次 FFmpeg（提取原始帧 → 生成压缩片段 → 提取压缩帧），4 张就是 12 次串行调用。

**建议**：不同时间点的预览帧之间无依赖，可并行。但要注意 FFmpeg 并发资源占用——建议受限于 `resourceGuard` 的并发位，或者简单用 `Future.wait` 但限制并发数为 2-3：

```dart
// 伪代码：并行生成，限制并发
final batches = <List<PreviewFramePair>>[];
for (var i = 0; i < defaultRatios.length; i += concurrency) {
  final slice = defaultRatios.skip(i).take(concurrency).toList();
  final pairs = await Future.wait(
    slice.asMap().entries.map((e) => _generateSingleFrame(...)),
  );
  batches.add(pairs);
}
```

---

## 四、P2 问题详解

### P2-1：preset 固定 slow

`default_compression_advisor.dart:10` 所有压缩都用 `slow`。x264 的 slow 比 medium 慢约 2x，质量提升约 5-10%。对追求速度的用户没有出口。

**建议**：可在 `AppSettings` 增加 `encodingSpeed` 偏好（fast/medium/slow），或基于 `smartPreset` 自适应：compact/chat 用 medium，clear/balanced 用 slow。

---

### P2-2：硬件编码走 CPU lanczos scale

`ffmpeg_video_argument_builder.dart:453` 用 `flags=lanczos`（高质量软件缩放）。当用 VideoToolbox/NVENC 时，scale 仍走 CPU，成为瓶颈。

**建议**：对硬件编码器用对应的硬件 scale 滤镜（`scale_vt`/`scale_cuda`/`scale_qsv`），软件编码器保持 lanczos。需要做能力探测，复杂度较高，可作为进阶优化。

---

### P2-3：Windows 内存检测缺失

`local_execution_resource_guard.dart:121-134` 只在 macOS/Linux 检测内存，Windows 返回 null，导致并发判断退化为仅看 CPU 核数。

**建议**：Windows 用 `systeminfo` 或 WMI 查询：

```dart
if (Platform.isWindows) {
  final result = Process.runSync(
    'powershell',
    ['-Command', '(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory'],
  );
  if (result.exitCode == 0) {
    return int.tryParse(result.stdout.toString().trim());
  }
}
```

---

### P2-4：缺少 -stats_period

FFmpeg 默认 progress 输出间隔 0.5s。对几秒的短视频，进度更新只有 2-3 次，跳跃明显。

**建议**：在 `-progress pipe:1` 旁加 `-stats_period 0.2`（FFmpeg 4.4+）：

```dart
'-progress', 'pipe:1',
'-stats_period', '0.2',
```

---

### P2-5：VFR/重滤镜 progress 倒退

`local_ffmpeg_process_observer.dart:157-167` 的 `calculateProgress` 只 clamp 上限，未处理倒退。HDR tonemap（zscale+tonemap）有缓冲，out_time 可能回跳，导致进度条回退。

**建议**：记录上次 progress，单调递增：

```dart
double? _lastProgress;
double? calculateProgress(int outTimeUs, MediaTask task) {
  // ... 原计算 ...
  final progress = (outTimeUs / durationUs).clamp(0, 0.999).toDouble();
  if (_lastProgress != null && progress < _lastProgress!) {
    return _lastProgress;  // 不回退
  }
  _lastProgress = progress;
  return progress;
}
```

（注意 observer 是无状态单例调用，需把 lastProgress 提到 observe 调用作用域内。）

---

## 五、优化优先级建议

**立即修（稳定性）**：
1. P0-1 ffprobe 超时 kill 进程
2. P0-2 ffmpeg stall detection

**短期修（效率/一致性）**：
3. P1-1 two-pass + CRF 逻辑修正
4. P1-2 码率表去重
5. P1-3 progress 字段升级

**中期优化（体验）**：
6. P2-4 -stats_period
7. P2-5 progress 单调化
8. P2-3 Windows 内存检测

**长期优化（性能）**：
9. P2-1 preset 自适应
10. P2-2 硬件 scale
11. P1-4 预览帧并行

---

## 六、做得好的地方（值得保持）

- 编码器能力探测（`FfmpegEncoderCapabilities`）+ 优雅降级，避免硬编码假设。
- HDR/Alpha/色彩元数据处理非常细致（tonemap peak 推断、Dolby Vision 拦截、色彩矩阵归一化）。
- 资源调度（`ExecutionResourceGuard`）考虑了 CPU 核数 + 内存 + 线程预算 + 重任务权重，比简单并发数限制科学得多。
- 压缩无效输出检测（`failIfOutputNotSmallerThanSource`）+ 图片格式 fallback 链，用户体验好。
- 任务队列的插队/抢占/连续执行设计完整。
- 日志记录完善（命令、stderr、结果摘要）。

这些是项目的核心竞争力，优化时应避免破坏。
