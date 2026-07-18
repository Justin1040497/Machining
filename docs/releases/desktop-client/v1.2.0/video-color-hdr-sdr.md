# 视频色彩与 HDR 转 SDR

## 版本事实

FrameLean 的视频压缩色彩链路在 v1.2.0 进入第一阶段修复：

- FFprobe 保存 SDR / HDR / Dolby Vision 判断所需的核心元数据。
- SDR 源优先保留源色彩信息，不再统一写成 BT.709。
- HDR10 / HLG 源通过 `zscale + tonemap` 转为 SDR BT.709。
- 用户开启“保持 HDR”时，任务配置限定为推荐方案并默认清晰优先，输出使用 HEVC Main10 和基础 BT.2020 / PQ / HLG metadata，不再把 `bt2020nc` 作为 `scale` 的 `out_color_matrix`。
- Dolby Vision Profile 5 或缺少 HDR10 兼容层的 Dolby Vision 不生成输出，直接给出可读错误。
- 硬件编码器质量参数使用独立映射，不再直接复用 CRF 数值。

对应长期决策见 `docs/decisions/260613-video-color-hdr-sdr-boundary.md`。

## 处理边界

- 当前输出仍以 SDR `yuv420p` 为主，优先解决常见压缩后变色、偏紫、变黑问题。
- HDR10 / HLG 的 tone mapping 依赖内置或用户指定 FFmpeg 中的 `zscale` 和 `tonemap`。
- Dolby Vision Profile 5 首版不做有损猜测转换；后续需要单独评估 `libplacebo` 或 `libdovi` 路线。
- CRF 预设校准不在本次修复内，后续应使用统一测试样本、输出体积和客观质量指标单独校准。

## 验证范围

- FFprobe 参数覆盖 chroma location、Mastering Display、MaxCLL / MaxFALL 和 Dolby Vision 字段。
- Drift schema 19 持久化并恢复新增分析字段。
- HDR10 / HLG 输出命令包含 `zscale + tonemap`。
- 保持 HDR 输出命令包含 `yuv420p10le` / Main10 / BT.2020 metadata，且 filter 不包含 `out_color_matrix=bt2020nc`。
- SDR BT.601 / SMPTE 170M 源保持对应输出 metadata。
- Dolby Vision Profile 5 在命令构造阶段失败。
- VideoToolbox `q:v` 等硬件质量参数不直接等于 CRF。
