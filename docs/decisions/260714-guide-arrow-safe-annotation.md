# 工作台引导箭头采用安全终点 + 最大长度 + 曲线偏移 + 裁剪区，不引入自动避障

## 日期

2026-07-14

## 状态

有效

## 背景

工作台背景引导层位于 `TaskList` 和 `BottomBar` 之下，初始实现中三条涂鸦箭头（任务操作、全部开始、添加按钮）存在以下问题：

1. 箭头过长，像连接两点的流程图连线，甚至贯穿大半个窗口。
2. 箭头终点直接落在任务卡片、底部栏或按钮内部，被上层组件遮挡，箭头头不可见。
3. 箭头主体使用幅度较大的双段波浪曲线，过于规则，不像参考图中的灰色手绘涂鸦批注。
4. 箭头头为简单开放双线，不够明显且可能落在被遮挡区域。

曾尝试引入通用路径规划系统解决遮挡：新增 `ArrowEndCalculator`、`ArrowPathValidator`（障碍物碰撞检测 + 多种子随机重试）、`ArrowRandom` 和独立的 `DoodleCurveGenerator`。该方案存在明显问题：

- 障碍物采样碰撞检测和随机重试在窗口尺寸变化时会让箭头形态不稳定；
- 引入大量与“三条固定用途箭头”不匹配的额外逻辑和测试成本；
- 实现中途产生未编译、未接入目标文件的半成品代码。

## 决策

引导箭头只服务于三个固定场景，每个目标位置和允许绘制区域都是明确的，因此不实现自动避障，改用四层显式约束：

### 1. 安全视觉终点

终点是“视觉终点”而非目标中心点：

- 任务箭头：停在最后一个任务卡片下方约 30 px。
- 全部开始箭头：停在大开始按钮顶部上方约 22 px。
- 添加按钮箭头：停在 `listViewportRect.bottom - 20`（BottomBar 顶部上方约 20 px）。

### 2. 最大长度限制

`DoodleArrow` 新增 `maxLength`。起点与终点距离超限时，终点不动，沿“终点指向起点”方向把实际绘制起点向终点收缩，只绘制末端最长 `maxLength` 的一段：任务箭头 270 px、全部开始 180 px、添加按钮 270 px、默认 280 px。

### 3. 单条三次贝塞尔 + 明确曲线偏移

`DoodleArrowGeometry.create` 改为单条 `cubicTo`，新增 `curveBias` 显式控制曲线向上或向下鼓起；随机只产生不超过 8 px 的法向扰动，不允许回头、自相交或大回旋；沿用固定 `seed` 保证同一箭头外观稳定。

### 4. 安全裁剪区

`DoodleArrow` 新增可选 `clipRect`，Painter 绘制前 `canvas.clipRect`。各场景使用明确背景安全区域（任务底部以下、开始按钮顶部以上、列表视口底部以上）。裁剪只是最后一层保护，正确的终点和曲线本身仍必须位于安全区内。

### 5. 开放式涂鸦箭头头

`createArrowHead` 改为返回 `DoodleArrowHead`（两条不对称外轮廓线 + 两条内部排线），不填充、不 `Path.close()`，长度约 12～17 px。

## 影响范围

- `lib/features/workbench/guide/arrow/doodle_arrow.dart`：新增 `maxLength`、`curveBias`、`clipRect` 参数并透传给 Painter。
- `lib/features/workbench/guide/arrow/doodle_arrow_geometry.dart`：重写 `create` 为限长单段 cubic；`createArrowHead` 改为开放涂鸦头 + 排线；新增 `DoodleArrowHead`。
- `lib/features/workbench/guide/arrow/doodle_arrow_painter.dart`：新增裁剪、新几何调用、三套笔刷（主线 / 回声 / 排线）、箭头头分层绘制、`shouldRepaint` 增补。
- `lib/features/workbench/guide/content/{task_operation,start_all,import}_group.dart`：替换三条箭头的起点、终点、裁剪区和 `DoodleArrow` 参数。
- 不修改 Scheduler、GuideState、GuideGeometry、Controller、WorkbenchShell、TaskList、BottomBar 和任务 Provider；不新增路径寻路、碰撞检测或重试系统。

## 关联事实

- `CONTEXT.md`
- `docs/lessons.md`（少量固定批注箭头优先用显式约束而非寻路）
- `CHANGELOG.md`（2026-07-14 引导箭头修复条目）
