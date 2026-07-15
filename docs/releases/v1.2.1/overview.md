# v1.2.1 版本概览

## 已发布事实

`v1.2.1` 已发布，应用构建版本为 `1.2.1+8`。本版本集中交付更新体验、媒体处理可靠性、任务夹工作流、受控并行、桌面设置和工作台背景引导。

公开更新默认使用 GitHub、Gitee 或备用下载地址。release 带任一外部地址时，客户端只展示日志与跳转入口，不直接下载或安装 EXE、DMG、ZIP。没有外部地址且服务端返回完整 package 元数据时，原 package 链仍可使用，但不作为默认发布门禁。

## 事实文档

| 文档 | 说明 |
| --- | --- |
| `release.md` | 面向用户的版本摘要、主要变化和已知问题 |
| `self-hosted-update-client.md` | 更新检查、外部下载入口和保留 package 客户端能力 |
| `self-hosted-update-server.md` | 独立服务端的更新 API、缓存、数据和可选 package 边界 |
| `admin-web-release-management.md` | Admin 版本日志、下载地址、审计和隐藏 package 能力 |
| `docs/decisions/260710-external-download-default.md` | 外部下载地址优先的发布决策 |

## 发布边界

- macOS 产物为 Universal 2 DMG；Windows 产物为 x64 当前用户安装器和可选便携 ZIP。
- package 自更新、COS ticket、Windows helper、macOS 私有 DMG 缓存和 Sparkle appcast 是保留能力，重新启用时单独验收。
- 服务端位于独立 [FrameLean-Backend](https://github.com/zhouycheng/FrameLean-Backend) 仓库；本仓库记录客户端契约和集成边界。
- 显式手动指定图片格式时，无效压缩会失败；自动询问是否改用其他格式仍是未提供的交互。
