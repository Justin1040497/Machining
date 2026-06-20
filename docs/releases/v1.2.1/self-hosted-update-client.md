# v1.2.1 自托管更新客户端

## 版本事实

FrameLean 在 v1.2.1 开发期把自托管更新客户端接入主体验。Windows 更新状态由 `appUpdateProvider` 统一管理并在启动后静默检查；macOS 自动检查只由 Sparkle 调度。设置页“关于”栏提供手动检查和下载入口，通知中心按版本去重展示更新通知，工作台顶部在存在更新或下载任务时保留持续入口。

客户端构建时通过 `FRAMELEAN_UPDATE_BASE_URL` 注入默认服务地址，也可以由托管配置覆盖。未配置该值且没有托管配置时，默认客户端不会看到可下载更新。

托管更新配置由只读配置快照承载，应用启动时读取一次，运行中的更新流程使用内存快照。macOS 优先读取 MDM managed preferences 和 `/Library/Application Support/FrameLean` 下的系统级 JSON，Windows 优先读取 `HKLM\Software\Policies\FrameLean` 和 `%ProgramData%\FrameLean` 下的系统级 JSON。普通用户可写的托管 JSON 会被视为不可信并忽略；隐藏文件只用于减少误触，不作为安全边界。

## 交互边界

- 设置页“关于”栏主按钮根据状态显示 `检查更新`、`检查中`、`现在更新`、下载百分比、`继续 xx%`、`重启更新` 或错误后的重试入口。
- 检查到新版本后，通知中心使用 `update:{platform}:{version}:{buildNumber}` 作为去重键，同一版本跨重启只保留一条更新通知。
- 工作台顶部入口不直接开始下载，而是打开版本日志弹窗；下载中以圆形进度展示。
- 版本日志页面读取服务端发布日志列表；当服务端列表为空但当前检查结果带有日志时，回退展示当前更新的日志。
- Windows 下载使用短期 ticket 解析出的 COS 预签名 URL。只有正确的 `206` / `Content-Range` 才会追加 partial；服务端忽略 Range 时覆盖写入，长度、SHA-256 或 Ed25519 校验失败时删除损坏包。
- Windows 自动安装由随包 `FrameLeanUpdaterHelper.exe` 执行；重启前统一暂停任务、终止 FFmpeg 并清理 partial，helper 再静默安装、核对注册表和 EXE build number、重启新版本。
- macOS 关于栏手动检查通过原生 Sparkle 2 MethodChannel 触发；下载、签名校验、安装和重启提示由 Sparkle 管理。Sparkle 重启前 delegate 会等待 Flutter 完成同一套任务停止和 partial 清理。

## 平台边界

- `windows-installer` 是 Windows 自动安装平台。更新载荷应为当前用户权限可静默覆盖安装的 Inno Setup 安装器；`windows-x64` ZIP 只作为便携下载 / 后台留存包。
- `macos-universal2` 通过 Sparkle appcast 自动更新。DMG 必须完成签名、公证，并通过 Sparkle `sign_update` 生成 EdDSA 签名。
- Linux / Web 工程目录存在，但不属于当前更新服务支持平台。

## 安全与完整性

- Windows 下载包必须通过 SHA-256 和 Ed25519 校验后才进入待安装状态；受信任公钥由发布构建内置，托管配置只能选择受信任 key id。
- macOS 更新包签名由 Sparkle `SUPublicEDKey` 和 appcast enclosure 的 `sparkle:edSignature` 校验。
- 更新服务地址不应写成带 `/api` 后缀的路径；客户端会自动拼接 `/api/v1/...`。
- Windows 正式发布脚本必须注入 HTTPS 更新地址、可信 key id、公钥和本地私钥 seed 文件，并生成 `*.update.json`；macOS 仅在签名、公证和 Sparkle 签名全部通过后生成同结构元数据。

## 卸载边界

- Windows `-RemoveAll` 会自行请求 UAC，清理应用数据、更新包、helper 请求和日志、临时目录、安装目录、`%ProgramData%\FrameLean` 及 `HKLM\Software\Policies\FrameLean`。
- macOS `--admin-cleanup` 通过 `sudo` 精确清理 `/Library/Application Support/FrameLean`；用户级支持目录、缓存、偏好和临时文件照常清理。
- MDM profile 由外部设备管理维护，卸载脚本不删除；用户导出的媒体文件不在扫描和删除范围内。

## 验证范围

- `appUpdateProvider` 状态机：Windows 自动检查、发现更新、ticket 下载、下载完成和 helper 启动；macOS 检查更新会分流到 Sparkle。
- 设置页、通知中心、工作台顶部入口和版本日志弹窗的状态展示。
- 断点续传、下载暂停、SHA-256 / Ed25519 校验失败和 helper 启动失败提示。
- Windows 干净环境覆盖安装、退出码、安装后版本确认和重启应用。
- macOS Sparkle appcast、托管 appcast 覆盖、签名错误拒绝和重启安装。
