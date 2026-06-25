# P0 修复说明：FFmpeg / FFprobe 稳定性

本次修复了全链路审查中标记的两个 P0 级稳定性问题。改动聚焦、接口保持兼容。

---

## P0-1：ffprobe 超时后僵尸进程

**文件**：`lib/infrastructure/services/input_runtime/ffprobe_media_analyzer.dart`

### 问题
原实现：
```dart
final result = await Process.run(
  ffprobePath,
  buildArguments(inputPath),
  stdoutEncoding: utf8,
  stderrEncoding: utf8,
).timeout(timeout);
```
Dart 的 `Future.timeout()` **只取消对 Future 的等待，不会终止底层子进程**。遇到损坏文件或网络盘卡住时，ffprobe 进程会在后台长期存活，批量导入分析时累积成僵尸进程，持续占用句柄与 CPU。

### 修复
改用 `Process.start`，手动收集 stdout/stderr 到 buffer，对 `exitCode` 加超时；超时分支主动 `kill(sigkill)` 并等待进程真正退出与流关闭：

```dart
final process = await Process.start(ffprobePath, buildArguments(inputPath));
final stdoutDone = process.stdout.listen(stdoutBuffer.addAll).asFuture<void>();
final stderrDone = process.stderr.listen(stderrBuffer.addAll).asFuture<void>();
try {
  final exitCode = await process.exitCode.timeout(timeout);
  await Future.wait([stdoutDone, stderrDone]);
  // ... 正常解析
} on TimeoutException {
  await _terminateProcess(process, stdoutDone, stderrDone);
  throw TimeoutException('FFprobe 分析超时（${timeout.inSeconds} 秒）: $inputPath', timeout);
}
```

`_terminateProcess` 内部 `kill(sigkill)` 后用 `Future.wait([exitCode, stdoutDone, stderrDone]).timeout(2s, onTimeout: () => [])` 做最终兜底，防止 kill 本身卡住拖死整个分析链路。

### 兼容性
- `analyze()` 签名不变。
- 仍抛 `TimeoutException`（与原 `.timeout()` 行为一致），调用方 catch 逻辑无需调整。
- 新增显式 `import 'dart:async';`。

---

## P0-2：FFmpeg observer 缺少 stall 检测

**文件**：`lib/infrastructure/services/execution/local_ffmpeg_process_observer.dart`

### 问题
原 `observe()` 只 `await process.exitCode`。当 ffmpeg 进程挂死（网络盘 IO 挂起、硬件编码器死锁、filtergraph 死循环）时，既不退出也不输出 progress，`exitCode` 永不完成，任务永久卡在 running 状态，占用执行位阻塞整个任务队列。

### 修复
1. 构造函数新增可配置参数：
   - `stallTimeout`（默认 60s）：进程静默超过该时长即视为挂死。
   - `stallCheckInterval`（默认 5s）：轮询间隔。
2. `observe()` 内维护 `lastActivity` 时间戳，`Timer.periodic` 周期检查；超阈值则 `kill(sigkill)` 并标记 `stalled`，让 `exitCode` Future 完成。
3. 主流程在 `exitCode` 返回后优先判断 `stalled`，返回明确的失败消息（"FFmpeg 进程无响应超时（N 秒无输出），已强制终止"）。
4. `finally` 中 `stallTimer.cancel()`，确保不泄漏定时器。

```dart
final stallTimer = Timer.periodic(stallCheckInterval, (_) {
  if (stalled) return;
  if (DateTime.now().difference(lastActivity) >= stallTimeout) {
    stalled = true;
    try { startedProcess.process.kill(ProcessSignal.sigkill); } on Object {}
  }
});
try {
  final exitCode = await startedProcess.process.exitCode;
  // ...
  if (stalled) return FfmpegProcessObservation.failed('FFmpeg 进程无响应超时（...），已强制终止');
  // ...
} finally {
  stallTimer.cancel();
}
```

### 阈值依据
ffmpeg 正常编码时（含 `slow` preset / 4K）progress 输出间隔通常 < 1 秒。60 秒完全静默基本可判定为死锁。该值可通过构造函数按场景调整（例如网络盘场景可放宽到 120s）。

### 流回调改造
为让 stall 检测能感知活动，`drainStdout` / `observeStdout` 新增 `onActivity` 回调，每次读到数据即刷新 `lastActivity`；`observeStderr` 的 `onLine` 回调同样刷新。`drainStdout` 由原来的 `stream.drain()` 改为 `await for`，以便在消费数据的同时触发回调。

### 兼容性
- 现有测试的 `FakeProcess` 流是同步完成的 `Stream.value`，测试运行在毫秒级，不会触发 60s 默认 stall，原有用例行为不变。
- `observeStdout`/`drainStdout` 是 observer 的内部方法，外部无调用，签名变更不影响公共 API。

---

## 新增测试

**文件**：`test/ffmpeg_process_observer_test.dart`

新增 `StallingProcess`（模拟挂死：流不产数据、`exitCode` 永不完成直到 `kill` 被调用）与对应测试：

```dart
test('kills stalled process and reports failure when no output exceeds stallTimeout', () async {
  final observer = LocalFfmpegProcessObserver(
    outputPathExists: (_) => true,
    stallTimeout: const Duration(milliseconds: 120),
    stallCheckInterval: const Duration(milliseconds: 40),
  );
  final process = StallingProcess();
  final result = await observer.observe(...);
  expect(result.status, FfmpegProcessObservationStatus.failed);
  expect(result.message, contains('无响应超时'));
  expect(process.killed, isTrue);
});
```

---

## 验证

请在本地运行（本机环境因沙箱限制无法执行）：

```bash
flutter test test/ffmpeg_process_observer_test.dart test/ffprobe_media_analyzer_test.dart
```

如需全量回归：

```bash
flutter test
```

---

## 未触及的后续项

P1/P2 项未在本次处理，建议按优先级另行排期：
- P1：two-pass + CRF 冗余、码率上限表重复维护、`out_time_ms` 字段歧义。
- P2：preset 速度出口、VFR 进度单调化、`-stats_period`、Windows 内存检测、预览帧串行。
