# 视频色彩修复采用 zimg HDR 转 SDR 边界

## 状态

有效

## 决策

- FFprobe 分析结果必须读取并持久化色度位置、HDR10 静态元数据、MaxCLL / MaxFALL、Dolby Vision Profile 和兼容 ID。
- SDR 源优先保留或按源信息正确转换色彩元数据，不再统一硬贴 BT.709。
- HDR10 / HLG 源默认通过 FFmpeg `zscale + tonemap` 转为 SDR BT.709，内置 FFmpeg 运行时必须启用 `libzimg` 并校验 `zscale` / `tonemap` 滤镜。
- 用户显式开启“保持 HDR”时，视频编码固定为 HEVC，使用 10-bit Main10 输出并保留基础 BT.2020 / PQ / HLG 色彩标记；任务配置限定为推荐方案并默认清晰优先，不允许自定义目标体积、微信发送或体积优先；该模式不承诺保留 Dolby Vision RPU 动态元数据。
- Dolby Vision Profile 5 或缺少 HDR10 兼容层的 Dolby Vision 首版直接拒绝命令构造，避免生成变黑、偏紫或严重偏色的输出。
- 压缩质量校准与色彩修复分开处理；CRF、NVENC CQ、QSV global quality、AMF QP 和 VideoToolbox `q:v` 不共用同一数值。

## 原因

- 变黑、偏紫和严重偏色的根因通常不是单一 CRF 问题，而是源色彩空间、HDR 转 SDR、Dolby Vision 兼容层和输出标签共同作用。
- `scale_vt` 或统一写 BT.709 metadata 只能覆盖部分 Apple HDR 场景，不能作为跨平台 HDR 转 SDR 策略。
- Dolby Vision Profile 5 没有可直接当作 HDR10 使用的兼容层，继续输出比直接失败更危险。
- 压缩预设需要使用统一样本、输出体积和客观质量指标独立校准，避免把色彩正确性和码率质量混成同一个开关。

## 约束

- 当前实现不处理 Dolby Vision RPU 重建、Profile 5 到 SDR 的高级映射，也不引入 `libplacebo`、`dovi_tool` 或独立 `libdovi`。
- 保持 HDR 输出的缩放滤镜不得把 `bt2020nc` 传给 `scale` 的 `out_color_matrix`，BT.2020 / PQ / HLG 通过输出色彩 metadata 表达。
- 内置 FFmpeg 更新时，macOS 和 Windows 发布脚本必须校验 `zscale` / `tonemap`。
- 后续调整 CRF / CQ / `q:v` 映射时，需要用样片和暗部渐变素材单独验证色带、暗部细节和体积变化。

## 关联事实

- `docs/releases/desktop-client/v1.2.0/video-color-hdr-sdr.md`
- `docs/develop/technology-stack.md`
- `docs/develop/data-model.md`
- `docs/develop/test-plan.md`
- `docs/reference/ffmpeg-license-distribution.md`
