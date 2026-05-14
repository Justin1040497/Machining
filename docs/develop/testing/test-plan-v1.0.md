# 测试计划 v1.0

## 自动化测试

提交前必须运行：

```bash
flutter analyze
flutter test
```

当前测试文件：

- `test/compression_advisor_test.dart`
- `test/ffmpeg_command_builder_test.dart`
- `test/ffmpeg_process_observer_test.dart`
- `test/ffmpeg_task_queue_runner_test.dart`
- `test/ffprobe_media_analyzer_test.dart`
- `test/preview_frame_generator_test.dart`
- `test/widget_test.dart`

## 覆盖范围

### 压缩建议

- 优先使用视频码率
- 视频码率缺失时使用容器码率
- 直接码率缺失时使用估算码率
- 极低码率视频需要确认

### 命令构造

- 普通压缩命令
- 目标码率压缩命令
- 自定义 CRF
- 输出格式
- 自定义输出文件名
- 输出路径冲突自动加后缀
- 分辨率参数
- 预览片段命令
- 编码后端兼容性

### 队列执行

- 有待处理任务时刷新状态
- 启动前台任务
- 任务切换
- 暂停和恢复
- 取消任务
- 取消全部执行
- 后台观测完成后写回状态
- FFmpeg 不可用
- 极限压缩确认拦截

### 进度观测

- 解析 `out_time_ms`
- 时长缺失时保持运行
- 退出码失败
- 输出文件缺失

### 预览

- 生成 5 组帧
- 缺失时长时拒绝
- 参数变化后过期
- 命令失败时报错
- 压缩帧失败时清理预览片段

## 手动验证

Release 前建议手动验证：

- 拖拽导入单个视频
- 拖拽导入多个视频
- 选择导入视频
- 修改输出目录
- 修改输出文件名
- 修改 CRF
- 生成预览
- 压缩完成并打开 Finder
- 暂停任务后继续
- 删除任务
- 重命名任务
- 低码率视频触发确认弹窗
- 移动 app 到 `Downloads` 后确认内置 FFmpeg 生效

## 内置 FFmpeg 验证

```bash
APP=build/macos/Build/Products/Release/machining.app

"$APP/Contents/Resources/ffmpeg/ffmpeg" -hide_banner -encoders | grep libx264
otool -L "$APP/Contents/Resources/ffmpeg/ffmpeg" | grep -E '/opt/homebrew|/usr/local/Cellar' || echo "OK: bundle ffmpeg is clean"
```

运行任务后查看日志：

```bash
LOG_DIR="$(getconf DARWIN_USER_TEMP_DIR)machining/ffmpeg-logs"
grep -h '^ffmpegPath:' "$LOG_DIR"/*.log | tail -1
```

## 1.1 测试补充

- DMG 安装测试
- 签名和公证验证
- 另一台 Mac 安装验证
- 磁盘不足
- 输出目录无权限
- 源文件丢失后重新定位
- 大文件长时间压缩
- 目标体积压缩结果验证
