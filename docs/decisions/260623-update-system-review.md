# 260623 应用更新系统全面审查报告

## 状态

审查中，待讨论。

## 审查范围

基于以下实际代码的逐行审查：

- 客户端：`lib/app/providers/app_update_provider.dart`、`lib/application/services/app_update/*`、`lib/infrastructure/services/app_update/*`、`lib/domain/value_objects/*update*`、`lib/features/workbench/pages/workbench_page/dialogs/update_release_notes_dialog.dart`
- 服务端：`server/src/main/kotlin/com/framelean/backend/service/UpdateService.kt`
- 测试：`test/app_update_provider_test.dart`
- 决策文档：`docs/decisions/260616-*`、`docs/decisions/260620-*`

## 已做得好的部分（先肯定）

1. **分层架构清晰**：domain / application / infrastructure 三层边界干净，依赖注入通过 Riverpod provider 组织，可测试性好。
2. **双校验机制**：SHA-256 完整性 + Ed25519 签名验签（Windows-installer 路线），签名支持 key id 信任链。
3. **断点续传**：HTTP Range + Content-Range 校验逻辑严谨，处理了 416、206、200 多种响应。
4. **跨重启恢复**：下载状态持久化到 JSON，重启后自动恢复已下载的包。
5. **企业托管配置**：MDM managed preferences / 系统级 JSON / Windows 注册表多来源，优先级清晰。
6. **下载 ticket 体系**：服务端 Redis 短期 ticket + TTL + IP 限流，下载 URL 预签名隔离。
7. **三入口 UX**：设置页主按钮 + 通知中心 + 工作台顶部，版本去重 key 保证不重复通知。

---

## 一、完整性检查

### 1.1【高】mandatory 和 minSupportedBuild 解析了但从未强制

**位置**：`AppReleaseInfo` 定义了 `mandatory` 和 `minSupportedBuild` 字段，`HttpAppUpdateClient._releaseFromJson` 从服务端解析，但全局搜索 `mandatory` 的使用点只有：领域模型定义、JSON 序列化/反序列化、测试 fixture。**没有任何 UI 或业务逻辑读取这两个字段来做强制阻断。**

**影响**：
- `mandatory: true` 的版本，用户仍可点击"后台下载"关闭弹窗继续使用旧版本
- `minSupportedBuild` 声明了最低支持版本，但当前 build 低于此值时不会阻断使用
- 对于安全修复版本，这意味着用户可以无限期忽略更新

**对比**：成熟方案（VS Code、Chrome、Electron autoUpdater）对 mandatory 更新会显示不可关闭的全屏阻断弹窗，minSupportedBuild 低于当前版本时会禁止进入主界面。

**建议**：
- 在 `AppUpdateNotifier.checkForUpdate` 返回 mandatory release 时，设置一个 `requiresBlockingUpdate` 标记
- 在 app 启动路由处检查此标记，若为 true 则导航到不可关闭的更新拦截页
- `UpdateReleaseNotesDialog` 根据 `release.mandatory` 隐藏"后台下载"按钮
- `minSupportedBuild > currentBuild` 时同样阻断，提示"当前版本过旧，必须更新"

### 1.2【高】无回滚机制

**位置**：`LocalUpdaterHelperLauncher.launch()` 启动 helper 后直接 `exit(0)`。安装失败通过 `update-failed.json` sentinel 文件通知（`AppUpdateNotifier._checkUpdateFailedSentinel`）。

**问题**：
- helper 进程如果崩溃在写入 sentinel 之前，主应用下次启动无法感知安装失败
- sentinel 是普通 JSON 文件，依赖 helper 正常运行，单点故障
- Windows 安装器失败后，旧版本已被替换（或部分替换），没有自动回滚到上一版本的能力
- macOS DMG 路线是手动安装，不存在回滚问题，但 Windows 路线完全没有

**对比**：Chrome 的更新系统在安装前备份旧版本目录，安装失败自动恢复。Windows MSI 安装器本身有回滚能力，但 NSIS / Inno Setup（看你用的是 .iss 文件，可能是 Inno Setup）不一定有。

**建议**：
- 短期：让 helper 写 sentinel 时用 atomic write（先写 .tmp 再 rename），并在 helper 多个关键节点写不同阶段的 sentinel
- 中期：helper 在安装前备份旧 exe / 目录，安装失败时恢复
- 长期：考虑用 Windows MSI 格式替代（自带事务回滚）

### 1.3【中】completed 状态定义了但从未使用

**位置**：`AppUpdateStatus` 枚举有 `completed` 值，但全局搜索没有任何地方将状态设为 `completed`。安装后直接 exit（Windows）或保持 downloaded（macOS）。

**影响**：状态机不完整，无法区分"安装中"和"安装完成"。

### 1.4【中】无周期性更新检查

**位置**：`AppUpdateNotifier.build()` 中 `scheduleMicrotask(() => unawaited(checkForUpdate(automatic: true)))` 仅在 app 启动时检查一次。

**影响**：长时间运行的应用（用户不重启）不会发现新版本。对于一个媒体处理工具，用户可能开着 app 几天不关。

**建议**：增加 `Timer.periodic` 每 4-6 小时静默检查一次，或借鉴 Sparkle 的 SULastCheckTime 机制。

### 1.5【中】无"稍后提醒" / snooze 机制

**位置**：`UpdateReleaseNotesDialog` 的 `_CurrentUpdateActions` 只有"下载/暂停/继续/安装"和"后台下载"两个按钮。

**影响**：不想立即更新的用户只能点"后台下载"关掉弹窗，下次启动又会被提醒。没有"明天再提醒"或"此版本不再提醒"选项。

### 1.6【低】Linux 无安装路径

**位置**：`_currentUpdatePlatform()` 返回 `linuxUpdatePlatform`，但 `LocalUpdaterHelperLauncher.launch()` 第一行 `if (!Platform.isWindows) throw UnsupportedError`。

**影响**：Linux 用户可以检查和下载更新，但无法安装。应至少在 UI 层隐藏 Linux 的下载按钮，或提供"打开下载目录"的降级方案。

### 1.7【低】无增量/差分更新

当前每次下载完整安装包。对于媒体处理工具可能体积较大（FFmpeg 等），增量更新能显著节省带宽。短期内优先级低，但长期值得考虑。

---

## 二、安全性分析

### 2.1【高】下载 URL（COS 预签名）未强制 HTTPS

**位置**：`LocalAppUpdatePackageDownloader.download()` 第 72 行 `httpClient.getUrl(ticket.downloadUrl)`，没有校验 `ticket.downloadUrl.scheme`。

**问题**：`EnterpriseUpdateConfig._readHttpsUrl` 校验了 `updateBaseUrl` 是 HTTPS，但实际下载 URL 来自服务端 `UpdateService.resolveDownloadTicket` 返回的 COS 预签名 URL。如果 COS 配置为 HTTP，下载在明文上进行，攻击者可中间人替换安装包。

**虽然** SHA-256 校验能发现篡改，但 SHA-256 值本身也来自同一个 HTTP 响应（`createDownloadTicket` 返回），攻击者可同时替换包和哈希。Ed25519 签名能防住这个（如果启用），但 macOS DMG 路线可能未启用签名。

**建议**：在 `download()` 入口校验 `ticket.downloadUrl.scheme == 'https'`，非 HTTPS 直接拒绝。

### 2.2【高】恢复路径跳过签名校验

**位置**：`AppUpdateNotifier._tryRestorePersistedDownload()` 第 187-189 行只做了 SHA-256 校验，没有调用 `ReleaseSignatureVerifier`。

**对比**：`LocalAppUpdatePackageDownloader.findExistingValidPackage()` 和 `download()` 都调用了 `_verifyPackage`（SHA-256 + 签名）。恢复路径是唯一只做 SHA-256 的地方。

**影响**：如果攻击者能写入 `update-download-state.json` 和替换本地包文件（需要本地写入权限），可绕过签名校验。虽然需要本地访问权限，但纵深防御原则下应保持一致。

**建议**：恢复路径也调用 `signatureVerifier.verify()`，或直接复用 `findExistingValidPackage()`。

### 2.3【中】macOS DMG 路线可能完全无签名校验

**位置**：`CryptographyReleaseSignatureVerifier.verify()` 第 24 行 `if (!config.requiresReleaseSignature) return`。`requiresReleaseSignature` 仅在 `_bundledReleaseSignatureRequired` 为 true 或 `trustedReleaseKeyIds` 非空时为 true。

**根据决策文档 260620**："macOS 手动 DMG 路线只需要注入更新服务地址"——意味着 macOS 构建可能不注入公钥，签名校验被跳过。此时只有 SHA-256 保护，而 SHA-256 值来自服务端 HTTP 响应，无法防篡改。

**建议**：macOS DMG 也应启用 Ed25519 签名，或至少在服务端发布时强制 macOS 包也有签名。

### 2.4【中】无证书锁定（Certificate Pinning）

**位置**：`HttpClient` 使用系统默认 TLS 配置。

**影响**：企业环境中的 MITM 代理（用自签 CA 证书）可以拦截更新检查请求，返回伪造的 release 信息。虽然签名校验能防住包替换，但检查阶段的元数据（版本号、更新日志）可被窥探或篡改。

**建议**：对更新服务的 HttpClient 配置证书锁定，或至少提供可配置的根证书选项。

### 2.5【中】下载 ticket 客户端未校验过期

**位置**：`AppUpdateDownloadTicket` 有 `expiresAt` 字段，但 `LocalAppUpdatePackageDownloader.download()` 从未检查 `DateTime.now().isBefore(ticket.expiresAt)`。

**影响**：ticket 过期后服务端会返回 403/410，但客户端不会提前检查，导致用户看到"更新包下载失败：403"而非"下载授权已过期，请重新检查更新"。

**建议**：download() 入口检查 `expiresAt`，过期时抛出明确的 `DownloadTicketExpiredException`，上层自动重新 `createDownloadTicket`。

### 2.6【低】下载 ticket 非单次使用

**位置**：服务端 `resolveDownloadTicket` 每次调用都生成新的预签名 URL 并记录下载事件，ticket 在 Redis TTL（10 分钟）内可多次 resolve。

**影响**：单个 ticket 可被复用多次下载（如果被截获），虽然 TTL 短，但仍是安全隐患。

**建议**：resolve 后从 Redis 删除 ticket（单次使用），或限制 resolve 次数。

---

## 三、容错与恢复

### 3.1【高】下载无超时机制

**位置**：`LocalAppUpdatePackageDownloader.download()` 第 118 行 `await for (final chunk in response)` 无超时。

**影响**：如果服务端 / CDN 接受连接但不发送数据（TCP 连接挂起），`await for` 会无限阻塞。下载状态卡在 `downloading`，用户只能手动暂停。

**建议**：用 `response.timeout(Duration(minutes: 1), onTimeout: ...)` 包装，或在 HttpClient 上设置 `idleTimeout`。增加chunk 间隔超时（如 60 秒无数据则视为失败）。

### 3.2【高】无自动重试

**位置**：`AppUpdateNotifier.startOrResumeDownload()` 的 `on Object catch (error)` 直接设置 `failed` 状态。

**影响**：网络瞬断、DNS 临时失败等瞬时错误直接判定为失败，用户必须手动重试。对于大文件（几百 MB 的安装包），一次网络抖动就要用户介入。

**建议**：对网络类异常（SocketException、HttpException、TimeoutException）实现指数退避重试，最多 3 次。重试时复用断点续传能力。

### 3.3【中】部分下载文件在非暂停错误时被删除

**位置**：`download()` 第 131-136 行 `on StateError` 删除文件后 rethrow。

**影响**：如果下载中途因"更新包大小超过服务端元数据"失败，已下载的部分被删除，重试从零开始。虽然 size mismatch 可能意味着数据损坏，但可以保留并让用户选择是否重新下载。

### 3.4【中】无磁盘空间预检

**位置**：`download()` 直接开始写入，无 `file.length()` + 磁盘剩余空间检查。

**影响**：磁盘空间不足时，`sink.add(chunk)` 抛出 OS 错误，用户看到 `FileSystemException: No space left on device`。提前检查能给更友好的提示。

### 3.5【中】状态持久化文件非原子写入

**位置**：`LocalAppUpdateDownloadStateStore.save()` 直接 `file.writeAsString(jsonEncode(json))`。

**影响**：如果 app 在写入过程中崩溃，文件可能截断/损坏。`load()` 的 `on Object { return null; }` 会吞掉错误返回 null，用户丢失下载状态需重新下载。

**建议**：写入临时文件后原子 rename：`file.writeAsString(...)` → `tempFile.rename(file.path)`。

### 3.6【中】exit(0) 过于 abrupt

**位置**：`LocalUpdaterHelperLauncher.launch()` 第 48 行 `exit(0)`。

**影响**：`Process.start` 是 detached 模式，`exit(0)` 立即终止进程，不给 Flutter / Riverpod / 数据库执行 dispose 的机会。未刷新的日志、未保存的设置可能丢失。

**建议**：先执行 graceful shutdown（`appController.dispose()` → `SystemNavigator.pop()` → 等 N 毫秒），再 exit。或用 `Process.run`（等待 helper 确认收到请求后再 exit）。

---

## 四、用户体验

### 4.1【中】无下载速度 / ETA

**位置**：`UpdateReleaseNotesDialog._CurrentUpdateActions` 只显示百分比 `state.progressPercent`。

**影响**：用户不知道还要等多久。对于 500MB 的安装包，"45%"和"还有 2 分钟"的信息量完全不同。

**建议**：在 `onProgress` 回调中记录时间戳，计算瞬时速度和 ETA，在 UI 显示"12.3 MB/s · 剩余 2 分 30 秒"。

### 4.2【中】错误消息过于技术化

**位置**：`startOrResumeDownload` 的 `on Object catch (error)` 直接 `error.toString()` 作为 `errorMessage`。

**影响**：用户看到 "HttpException: 更新服务返回 503: Service Unavailable" 而非"更新服务暂时不可用，请稍后重试"。

**建议**：建立错误分类映射（网络 / 服务端 / 磁盘 / 校验 / 签名），每类对应用户友好的文案和操作建议。

### 4.3【中】无后台静默下载选项

**位置**：用户必须手动点击"下载"才开始下载。

**影响**：安全更新依赖用户主动操作，延迟修补。很多成熟方案（Chrome、Firefox）默认后台下载，下载完成后提示安装。

**建议**：对非 mandatory 更新，提供"自动下载，准备好后提醒安装"选项（设置项）。对 mandatory 更新，默认自动下载。

### 4.4【低】进度回调的 stale guard 导致 UI 不更新

**位置**：`startOrResumeDownload` 的 `onProgress` 回调第 426-428 行：
```dart
if (state.asData?.value.release?.notificationDedupeKey !=
    release.notificationDedupeKey) {
  return;
}
```

**影响**：如果用户在下载期间触发了新的检查更新（比如网络恢复后自动检查），state 的 release 可能变化，导致进度回调被跳过，UI 进度条卡住。下载仍在后台继续，但用户看不到进度。

**建议**：用下载会话 ID 而非 release key 做 guard，确保当前下载会话的进度始终更新。

### 4.5【低】无"跳过此版本"选项

非 mandatory 更新应允许用户跳过特定版本，不再重复提醒。需要在本地记录 skipped 版本列表。

---

## 优先级排序建议

| 优先级 | 编号 | 问题 | 修复复杂度 |
|--------|------|------|-----------|
| P0 | 1.1 | mandatory / minSupportedBuild 未强制 | 中 |
| P0 | 2.1 | 下载 URL 未强制 HTTPS | 低 |
| P0 | 2.2 | 恢复路径跳过签名校验 | 低 |
| P0 | 3.1 | 下载无超时 | 低 |
| P1 | 3.2 | 无自动重试 | 中 |
| P1 | 1.2 | 无回滚机制 | 高 |
| P1 | 2.3 | macOS 可能无签名校验 | 中 |
| P1 | 3.6 | exit(0) 过 abrupt | 低 |
| P2 | 1.4 | 无周期性检查 | 低 |
| P2 | 3.4 | 无磁盘空间预检 | 低 |
| P2 | 3.5 | 状态文件非原子写入 | 低 |
| P2 | 4.1 | 无下载速度 / ETA | 中 |
| P2 | 4.2 | 错误消息技术化 | 中 |
| P3 | 1.5 | 无 snooze 机制 | 中 |
| P3 | 4.3 | 无后台静默下载 | 中 |
| P3 | 其余 | 见上文 | — |
