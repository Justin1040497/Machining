# v1.2.1 更新客户端

## 版本事实

FrameLean 在 v1.2.1 把更新检查接入主体验。Windows 和 macOS 统一由 `appUpdateProvider` 管理状态并在启动后静默检查；设置页“关于”栏提供手动入口，工作台顶部提供 L1 状态胶囊，L2 更新通知展示摘要和动作，通知中心按版本去重，L3 页面展示完整版本日志。

当前公开发布以 GitHub、Gitee 或备用下载地址为默认。`AppReleaseInfo` 同时支持外部地址和可选 package 元数据；只要 release 返回任一外部地址，客户端就只展示跳转按钮，不创建 download ticket，也不直接下载或安装 EXE、DMG、ZIP。

客户端构建时通过 `FRAMELEAN_UPDATE_BASE_URL` 注入默认服务地址，也可以由托管配置覆盖。未配置该值且没有托管配置时，默认客户端不会看到服务端更新。

托管更新配置由只读快照承载，应用启动时读取一次。macOS 优先读取 MDM managed preferences 和 `/Library/Application Support/FrameLean` 下的系统级 JSON，Windows 优先读取 `HKLM\Software\Policies\FrameLean` 和 `%ProgramData%\FrameLean` 下的系统级 JSON。普通用户可写配置视为不可信并忽略；隐藏文件只用于减少误触，不作为安全边界。

## 默认外部下载流程

- 自动或手动检查发现新版本后，L2 更新通知展示版本、摘要、平台和完整日志入口。
- release 提供 GitHub、Gitee 或备用地址时，弹窗按实际存在的地址展示“前往 GitHub”“前往 Gitee”或“备用地址”。
- 点击外部地址通过平台外链服务调用系统浏览器；打开失败时写入可读通知。
- 非 mandatory 更新可点“下次再说”记录当前版本 snooze。同版本后续自动检查只显示 L1，不再自动弹窗；新版本发布后 snooze 自动失效。
- 完整版本日志页从 L2 或历史更新通知进入；服务端日志列表为空时，回退展示当前检查结果携带的日志。

## 保留 package 路线

没有外部下载地址且 release 提供完整 package 元数据时，客户端仍保留原自更新能力：

- Windows 下载使用短期 ticket 和 COS 预签名 URL，严格校验 `206` / `Content-Range`、size、SHA-256 和 Ed25519；损坏包会被删除。
- Windows 安装由随包 `FrameLeanUpdaterHelper.exe` 执行。重启前暂停任务、终止 FFmpeg 并清理 partial；helper 等待主进程退出、静默覆盖安装、核对版本，失败时重试并写入失败哨兵。
- macOS package 路线使用 JSON latest / ticket 把 DMG 保存到应用支持目录 `updates/<version>/macos-universal2/`，校验后打开所在位置，由用户手动挂载和安装。
- 下载状态持久化到本地 JSON；重启恢复路径会重新检查文件与 SHA-256。Sparkle MethodChannel 只有构建显式设置 `FRAMELEAN_USE_SPARKLE_UPDATES=true` 时启用。
- release 同时提供外部地址和 package 时，外部地址优先，package 下载链被主动绕过。

## 安全与发布边界

- 外部下载入口只接受服务端保存的 HTTP(S) 地址；最终下载页和安装包可信度由对应外部平台、发布说明和用户确认共同承担。
- 更新服务地址不应带 `/api` 后缀，客户端会自动拼接 `/api/v1/...`。
- 保留 Windows package 路线必须通过 SHA-256 和 Ed25519 验签；受信任公钥由发布构建内置，托管配置只能选择受信任 key id。
- 保留 macOS 手动 DMG 路线至少校验服务端元数据中的 SHA-256；没有 Apple Developer ID 签名 / 公证时不会自动替换应用。
- canonical release 脚本继续要求 HTTPS 更新地址、Windows key id、公钥和私钥文件，并生成 `*.update.json`。这是保留 package 路线的 fail-closed 约束，不是当前 Admin 外部地址发布的 package 必填要求。

## 卸载边界

- 应用内不提供卸载入口；macOS 通过拖拽 `.app` 到废纸篓手动删除，Windows 通过“已安装的应用”标准卸载流程处理。
- MDM profile 由外部设备管理维护；用户导出的媒体文件不在任何自动清理范围内。

## 验证范围

- 外部地址 release：自动 / 手动检查、L1 / L2 / L3、通知去重、snooze、GitHub / Gitee / 备用按钮和外链打开失败提示。
- 外部地址优先：release 同时带外部地址和 package 时，不查找本地 package、不创建 ticket、不启动下载。
- package 兼容：Windows ticket 下载、断点续传、SHA-256 / Ed25519、helper 启动；macOS 私有缓存、手动打开 DMG 和重启恢复。
- 托管配置来源、HTTPS 服务地址、受信任 key id 和 Sparkle 显式启用边界。
