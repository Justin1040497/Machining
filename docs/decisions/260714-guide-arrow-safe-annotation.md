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

引导箭头只服务于三个固定场景，每个目标位置和允许绘制区域都是明确的，因此不实现自动避障，改用显式约束：

### 1. 安全视觉终点

终点是“视觉终点”而非目标中心点：

- 任务箭头：停在最后一个任务卡片下方约 36 px，为向上的强调线保留完整空间。
- 全部开始箭头：停在大开始按钮顶部上方约 30 px，为向下的强调线保留完整空间。
- 添加按钮箭头：停在 `listViewportRect.bottom - 20`（BottomBar 顶部上方约 20 px）。

### 2. 最大长度限制

`DoodleArrow` 新增 `maxLength`。起点与终点距离超限时，终点不动，沿“终点指向起点”方向把实际绘制起点向终点收缩，只绘制末端最长 `maxLength` 的一段：任务操作与全部开始箭头均为 245px，添加按钮箭头为 180px，默认值为 280px。

### 3. 双段三次贝塞尔 + 明确曲线偏移

`DoodleArrowGeometry.create` 使用两段连续 `cubicTo` 形成可调深度的手绘曲线，`curveBias` 显式控制主要鼓起方向；三条箭头统一使用全部开始箭头的自然单弧比例和曲率强度 72，只根据目标方向翻转弧面。任务操作与全部开始箭头最大长度为 245px，实际起终点距离约 190～215px；添加按钮箭头为避免压过居中内容，缩短到约 145～165px，最大长度为 180px。可选 `targetDirection` 固定曲线进入目标点时的最终切线，任务箭头向上，全部开始与添加按钮箭头向下。默认控制点在目标方向上的投影保持单调，随机只产生轻微法向扰动，不允许回头或自相交；沿用固定 `seed` 保证同一箭头外观稳定。

### 4. 安全裁剪区

`DoodleArrow` 新增可选 `clipRect`，Painter 绘制前 `canvas.clipRect`。各场景使用明确背景安全区域（任务底部以下、开始按钮顶部以上、列表视口底部以上）。裁剪只是最后一层保护，正确的终点和曲线本身仍必须位于安全区内。

### 5. 参考图式铅笔复描与封闭排线箭头头

箭头主体使用 3.8px 圆角主线、轻微偏移复描和 seeded 短纹理。`createArrowHead` 返回约 23～30px 的 `DoodleArrowHead`，包含不对称封闭轮廓、位于中轴的真实 `baseNotch` 凹口坐标、单位方向、低透明填色、三道内部排线与短终点强调线；不绘制容易在短箭头中形成反向箭头错觉的起点装饰。Painter 在凹口后方截断主体，并用与剩余距离成比例的短三次贝塞尔连接到 `baseNotch`；两端控制柄分别延续主体切线和箭头轴线，不添加独立直线段，从而让三条箭头都以相同方式自然进入凹口，避免翼边重合、方钩和折角。所有装饰仍由内容组的 `clipRect` 裁剪，不得覆盖任务卡片或底栏。

任务操作内容组使用工作台宽度的 18% 计算箭头水平跨度，并限制为 185～220px。任务操作和全部开始提示文字以对应箭尾为定位基准，沿箭头反方向布置并保留 14px 视觉间距；任务双行文案右对齐，避免文本框内部留白被误认为额外距离。空队列场景将 `ImportGuideGroup` 与 `AddButtonArrowGroup` 保持为两个独立 Stack 子层：前者把导入图标和三行说明作为一个整体居中，后者只绘制指向添加按钮的短箭头。引导文案不使用逗号，需要停顿时以空格替代。

Guide 场景根节点的可见透明度统一设为 50%，让提示文字、图标和箭头作为一个整体降低视觉权重；淡入淡出时长、场景切换和各元素原有颜色透明度保持不变。

### 6. 任务场景使用共享安全通道

任务操作与全部开始不再分别占用整块尾部空间。`TaskWorkspaceGuideLayout` 统一测量最后一张任务卡下方 16px 到开始按钮上方 10px 的安全矩形：高度达到 360px 时划分为上下两条通道并保留 28px 间距，180～359px 时只保留优先级更高的全部开始引导，不足 180px 或列表可滚动时隐藏。布局使用固定箭头长度和曲率计算箭身、封闭头、强调线与文本的最终视觉边界；双通道校验失败时降级为全部开始，单通道仍越界时隐藏，不通过压缩箭头换取空间。

背景双击导入不再限定空队列。任务存在时由任务列表外层的原始主按钮指针监听识别双击，并通过任务与任务夹的全局矩形排除前景内容；因此只在未占用背景触发，不向任务卡片手势系统增加竞争性的双击识别器。

## 影响范围

- `lib/features/workbench/guide/arrow/doodle_arrow.dart`：提供 `maxLength`、`curveBias`、`targetDirection`、`clipRect` 参数并透传给 Painter。
- `lib/features/workbench/guide/arrow/doodle_arrow_controller.dart`：将 seeded 箭头头缩放收敛到 0.94～1.06，保留自然差异但避免尺寸跳变。
- `lib/features/workbench/guide/arrow/doodle_arrow_geometry.dart`：`create` 使用限长双段 cubic；`createArrowHead` 生成封闭排线头和强调线。
- `lib/features/workbench/guide/arrow/doodle_arrow_painter.dart`：负责安全裁剪、主线 / 复描 / 纹理 / 排线分层绘制和逐段动画；`shouldRepaint` 覆盖全部视觉输入。
- `lib/features/workbench/guide/content/{task_operation,start_all,import}_group.dart`：替换三条箭头的起点、终点、裁剪区和 `DoodleArrow` 参数；任务场景消费共享布局结果。
- `lib/features/workbench/guide/models/{guide_geometry,task_workspace_guide_layout}.dart` 与 Scheduler：按实际空间解析双引导、仅全部开始或隐藏状态，并在进入任务场景前完成最终边界校验。
- 不修改 GuideState、WorkbenchShell、TaskList、BottomBar 和任务 Provider；不新增通用路径寻路或随机重试系统。

## 关联事实

- `CONTEXT.md`
- `docs/lessons.md`（少量固定批注箭头优先用显式约束而非寻路）
- `CHANGELOG.md`（2026-07-14 引导箭头修复条目）
