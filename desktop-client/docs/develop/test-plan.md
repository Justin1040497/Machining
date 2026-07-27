# Desktop Client 测试计划

## 测试目标

验证 Desktop Client 只承担用户交互、持久化和 FEngine 投影职责；媒体元数据、预览帧、视频缩略图与执行均通过 FEngine/FLL 完成。测试必须拒绝重新引入 `ffmpeg` / `ffprobe` executable、shell 命令或 Client 侧 native 命令规划。

## 必跑命令

Desktop Client：

```bash
cd desktop-client
dart format --output=none --set-exit-if-changed <changed dart files>
flutter analyze
flutter test
```

FLL / FEngine 联动变更：

```bash
scripts/build/with_bundled_ffmpeg.sh cargo check --manifest-path fll/Cargo.toml --all-targets --locked
scripts/build/with_bundled_ffmpeg.sh cargo test --manifest-path fll/Cargo.toml --locked
scripts/build/with_bundled_ffmpeg.sh cargo check --manifest-path fengine/Cargo.toml --all-targets --locked
scripts/build/with_bundled_ffmpeg.sh cargo test --manifest-path fengine/Cargo.toml --locked
scripts/verify/engine_client_e2e.sh
```

零媒体 CLI 扫描：

```bash
rg -n 'Process\.(start|run|runSync).*?(ffmpeg|ffprobe)|Command::new\(\s*"ffmpeg|ffmpeg\.exe|ffprobe\.exe' . \
  --glob '!build/**' --glob '!dependencies/**' --glob '!**/.dart_tool/**' --glob '!**/target/**'
```

## 自动化覆盖范围

### 分层与持久化

- Domain 不依赖 Flutter、Drift、文件系统或 native media API。
- Drift 保存任务、任务夹、设置、FLL Snapshot 投影、request identity、queue revision 和 sequence。
- 设置模型不包含自定义媒体 CLI 路径。
- 任务夹只在 Client 中存在；提交时按稳定顺序摊平成独立 Engine 工作。

### FEngine Gateway

- Hello、心跳、关闭、重连和同 session 对账。
- length-framed JSON 编解码、sequence 单调性和 request id 幂等。
- `AnalyzeMedia` payload 与 `AnalysisCompleted` Snapshot 映射。
- `GeneratePreviewFrames` payload、Control queue metadata 与 `PreviewFramesReady` artifact 映射。
- `GenerateVideoThumbnail` payload、Control queue metadata 与 `VideoThumbnailReady` artifact 映射。
- `SubmitExecution` 原样提交用户 selection、analysis id/revision 和输出策略。
- Worker error 与 FLL engine code 保持结构化，不从 stderr 文本推断任务真相。
- 真实 daemon E2E 通过 `FRAMELEAN_TEST_REMUX_PROGRESS_DELAY_MS` 仅在 debug
  FEngine 内为每个真实 libav packet 回调注入短暂停顿，以稳定验证 Gateway
  两次安全插队、LIFO 自动恢复与同 session 重连；release binary 不读取该变量。

### 预览帧与缩略图

- 预览用例使用分析时长生成固定 ratio 时间点并提交源事实。
- 返回 artifact 数量不完整时 fail closed。
- 预览 UI 使用单一源媒体帧模型，不伪造压缩后对比帧。
- 视频缩略图 pending 请求去重；成功文件进入内存缓存并触发刷新。
- 缩略图失败保留占位图，不修改任务状态。
- 图片卡片继续直接使用本地图片文件。

### 分析、配置和执行闭环

- 导入任务进入 `await_analysis`，随后投影分析排队、分析中和 `ready`。
- `AnalysisCompleted` 直接提供可选候选、预设、估算和参数投影；Client 不调用额外配置解析命令。
- 用户点击开始后，selection 原样提交给 FEngine。
- 普通等待队列与 Video/Auxiliary 两个 LIFO 恢复栈分开投影。
- 插队顺序遵守安全点暂停和 LIFO 恢复；用户暂停不会被自动恢复。
- 双 revision 重排冲突不会部分应用。
- 完成、失败和取消终态在离线重连后可通过 Engine Snapshot 恢复。

### 错误与恢复

- 源文件缺失或源 size/mtime 不匹配时不生成有效 Snapshot/artifact。
- 协议断帧、非法 payload、WorkerBusy 和 sequence gap 具有明确恢复路径。
- 严格限定的单视频、无音频 software decode -> 可选 swscale -> libx264 -> MP4 可以真实完成；音频、多流、HDR、任意 Plugin Processor 桥接和其他未资格化转换组合返回 `ENGINE_EXECUTION_CHAIN_NOT_READY`，不会伪造进度或成功输出。
- 输出目录不可写、磁盘空间不足、文件占用和发布失败映射为可读失败。
- 删除任务、清空列表、应用退出和更新准备会先通过 Engine control API 取消或暂停相关工作。

## 手动验证范围

### 媒体闭环

1. 导入一个视频，确认状态依次进入等待分析、分析排队、分析中和等待开始。
2. 打开配置面板，确认内容来自分析 Snapshot；不要出现媒体 CLI 路径设置。
3. 打开预览，确认生成 5 张源媒体 BMP 帧且 UI 可读取。
4. 返回工作台，确认视频缩略图异步出现；快速重复刷新不产生重复请求。
5. 点击开始，确认任务进入 FEngine execution lane；未实现的转码链显示明确的 `ENGINE_EXECUTION_CHAIN_NOT_READY` 用户提示。

### 队列与插队

1. 同时导入同类型 A1、A2、A3，确认 Client 形成任务夹但 Engine 队列中是独立任务。
2. 同时导入 1 个 HDR 和 4 个 SDR 视频，确认 4 个 SDR 留在任务夹，HDR 视频释放为独立总队列项；同时导入 4 个 HDR 和 4 个 SDR 视频时确认形成两个任务夹。
3. 打开任务夹配置，确认仅显示所有成员共同可用的预设或候选；无共同配置时提示解散或移除不兼容任务，不能部分保存。
4. A1 运行时点击 A3 开始，确认 A1 安全暂停、A3 成为活动项。
5. A3 运行时点击 A2 开始，确认 A2 完成后恢复 A3，最后恢复 A1。
6. 拖拽分析或执行等待项，确认实际 Engine queue revision 和顺序变化。

### 重连

1. 保持 daemon Worker 运行并关闭 Client 连接。
2. 在任务继续期间重新打开 Client。
3. 确认同 session 重连，队列、活动项、LIFO 栈、用户暂停和终态按 Engine Snapshot 恢复。

## 静态 FEngine / libav 构建验证

macOS：

```bash
scripts/build/build_ffmpeg_macos_arch.sh arm64
scripts/build/build_fengine_macos_arch.sh arm64
otool -L build/dependencies/fengine/macos-arm64/framelean-engine
```

最终二进制不得列出动态 `libav*.dylib`。Universal 2 构建必须验证 x86_64 与 arm64 slice。

Windows：

```powershell
bash scripts/build/build_ffmpeg_windows_x64.sh
bash scripts/build/build_fengine_windows_x64.sh
objdump -p build/dependencies/fengine/windows-x64/framelean-engine.exe
```

最终二进制不得依赖动态 libav 或 GNU runtime DLL。Desktop Release 目录只携带 FEngine，不包含 `ffmpeg.exe` / `ffprobe.exe`。
