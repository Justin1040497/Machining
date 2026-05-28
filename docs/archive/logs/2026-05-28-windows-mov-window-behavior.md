# 2026-05-28 Windows MOV Window Behavior

## Background

Windows 测试暴露出三个发布前问题：

- 使用管理员身份运行时，资源管理器中的文件无法手动拖入应用，但点击添加按钮可以选择视频。
- 大写 `.MOV` 后缀的视频在 Windows 和 macOS 上导入后点击开始会失败。
- Windows 应用启动默认出现在左上角，希望默认居中。

## Diagnosis

管理员模式拖拽属于 Windows 权限隔离限制：管理员进程和普通资源管理器权限级别不同，拖拽消息可能无法送达应用窗口。点击添加按钮由应用主动打开文件选择器，不依赖跨进程拖拽消息，所以仍然可用。

大写 `.MOV` 导入识别已经按扩展名小写化处理，但 macOS 和 Windows 常见文件系统大小写不敏感。如果用户配置的 MOV 输出路径与源文件只差大小写，例如 `clip.MOV` 和 `clip.mov`，原先的字符串级路径比较会认为它们不同，导致 FFmpeg 尝试写回等价源文件路径并失败。

Windows 窗口入口原先把启动坐标写死为 `(10, 10)`，因此默认显示在左上角。

## Fix

- 输出路径比较在 macOS / Windows 上按大小写不敏感路径处理，发现与源文件等价时自动追加数字后缀。
- FFmpeg 非零退出时把 stderr 尾部错误一起写入失败消息，便于定位 MOV 容器、编码器或路径问题。
- Windows runner 启动时按主显示器工作区计算居中坐标。
- Windows runner 增加当前进程管理员权限检测，应用在管理员模式下显示拖拽限制提示。

## Validation

- 新增 `.MOV` 扩展名识别回归测试。
- 新增大小写不敏感 MOV 输出路径冲突回归测试。
- 新增 FFmpeg 失败 stderr 尾部消息回归测试。
- 通过 `flutter analyze`。
- 通过 `flutter test`。
- Windows 原生窗口居中和管理员拖拽提示需要在 Windows 机器上手动验证。
