# Clean Architecture 依赖装配与平台边界

## 状态

有效。

## 背景

FrameLean 的目录已经按 `domain`、`application`、`infrastructure`、`features` 和 `app` 分层，但此前仍存在几类依赖方向漂移：

- `infrastructure/providers` 中的 Riverpod Provider 同时导入 application、infrastructure 和 features。
- 设置页与工作台直接持有文件选择、外链打开和文件定位等平台实现。
- 设置页、通知中心会反向引用工作台的主题、表单控件和通知组件。
- application 通知模型携带 Flutter `IconData`，使业务编排依赖展示框架。

这些问题不会立即破坏功能，但会让基础设施层承担装配职责、让 feature 之间横向耦合，并增加后续测试和替换平台实现的成本。

## 决策

1. Riverpod Provider 统一放在 `lib/app/providers/`，由 app 作为 composition root 装配 application、infrastructure 和 features。
2. 文件选择、外链打开、文件定位和主题首帧缓存统一在 `lib/application/services/platform/` 定义 port，在 `lib/infrastructure/services/platform/` 提供桌面实现。
3. 设置、通知中心和工作台共同使用的主题扩展、领域展示映射、表单控件和通知组件统一放在 `lib/app/`。
4. application 层只表达业务动作和数据，不携带 Flutter 展示类型；图标等视觉映射由 app 展示层完成。
5. `test/architecture_dependencies_test.dart` 自动检查核心目录的导入方向，阻止分层约束回退。

## 结果

- infrastructure 重新聚焦仓储、数据库、运行时和平台实现。
- features 通过 Provider 和 application port 获取能力，不再直接依赖 infrastructure。
- app 明确承担启动、路由、依赖装配和跨功能共享展示职责。
- 输出设置批量应用逻辑从 feature notifier 下沉为 application use case，设置保存协调器不再依赖工作台实现。

## 边界

- 本次决策不改变数据库 schema、媒体处理规则和用户可见主流程。
- `app` 可以依赖各层完成装配，但 domain、application、infrastructure 和 features 仍遵守单向依赖约束。
- 具体平台实现可以继续使用 Flutter 插件；application port 不得暴露插件或 Flutter 类型。

## 关联

- `docs/develop/architecture.md`
- `docs/develop/test-plan.md`
- `docs/releases/v1.2.0/release.md`
