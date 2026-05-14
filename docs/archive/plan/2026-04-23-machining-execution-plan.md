# Machining v1.1 Execution Plan

## 当前基线

当前项目以 `1.0.0+1` 作为基线。1.0 已经完成 macOS Apple Silicon 本地视频压缩主链路，不再把早期 `v0.x` 计划作为当前执行口径。

1.0 已完成：

- Flutter Desktop 工作台
- 视频导入和拖拽导入
- FFprobe 媒体分析
- FFmpeg 压缩和格式输出
- 预览帧生成
- 任务队列
- 暂停、继续、取消、删除、重命名
- 完成弹窗和 Finder 打开
- 内置 FFmpeg / FFprobe
- Release app 构建
- 自动化测试

## v1.1 目标

把 1.0 从“本地可用”推进到“小范围分发可用”。

1.1 不重做核心压缩链路，重点处理：

- 分发
- 许可
- 异常体验
- 真实素材验证
- 发布检查

## 任务 1：发布合规

完成项：

- 增加 `LICENSE`
- 增加 `THIRD_PARTY_NOTICES`
- 整理 FFmpeg / x264 源码获取说明
- 确认 app 包内许可证目录结构
- 检查 README 和分发文档中的 GPL 说明

验收：

- 用户拿到 Release 包时能看到许可证信息
- 仓库能说明 FFmpeg 是如何构建的
- `scripts/build_ffmpeg_macos_arm64.sh` 是可复现入口

## 任务 2：macOS 分发

完成项：

- 制作 DMG
- 配置代码签名
- 配置 Apple 公证
- 形成安装说明
- 在另一台 Apple Silicon Mac 上验证

验收：

- 下载后可打开 DMG
- 拖入 Applications 后可启动
- Gatekeeper 不阻止正常启动
- app 内置 FFmpeg 生效

## 任务 3：异常体验

完成项：

- 源文件缺失后的重新定位入口
- 输出目录无权限提示
- 磁盘空间不足提示
- FFmpeg 启动失败提示
- FFprobe 分析失败提示

验收：

- 用户知道失败原因
- 用户知道下一步能做什么
- 错误不会让任务队列进入不可恢复状态

## 任务 4：任务历史

完成项：

- 区分当前队列和历史记录
- 支持清理已完成任务
- 支持从历史打开输出文件
- 支持失败任务重新处理

验收：

- 长期使用后任务列表不会混乱
- 用户可以找回最近输出结果

## 任务 5：目标体积压缩

完成项：

- 设计目标体积输入
- 根据时长估算目标码率
- 极低目标体积给出确认
- 增加命令构造测试
- 用真实素材验证结果

验收：

- 正常目标体积能产出接近预期的文件
- 不合理目标体积会阻止或警告
- 失败时保留明确错误

## 任务 6：真实素材基准

完成项：

- 准备样本集
- 记录源文件参数
- 对比 CRF、码率和硬件编码
- 输出默认参数建议

验收：

- 形成可重复的基准记录
- 1.1 默认参数有数据支撑

## 质量门槛

每次准备合并前运行：

```bash
flutter analyze
flutter test
```

每次准备发布前运行：

```bash
scripts/build_ffmpeg_macos_arm64.sh
flutter build macos --release
```

并验证：

```bash
LOG_DIR="$(getconf DARWIN_USER_TEMP_DIR)machining/ffmpeg-logs"
grep -h '^ffmpegPath:' "$LOG_DIR"/*.log | tail -1
```

输出路径应指向：

```text
machining.app/Contents/Resources/ffmpeg/ffmpeg
```
