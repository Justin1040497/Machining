# 启动时主题缓存优化

## 问题

`main()` 中原先等完整 SQLite / Drift 初始化 + `loadSettings()` 查询完成后才 `runApp()`，串行链路为：

```
AppDatabase() → LazyDatabase → getApplicationSupportDirectory() → NativeDatabase.createInBackground()
  → _loadInitialSettings() → Drift SELECT → runApp()
```

为了一个 `themeMode` 字段等整个 ORM 就绪，启动较慢，且 `runApp()` 之前用户看到的是原生窗口默认背景。

## 方案

新增轻量级 JSON 缓存文件 `theme_prefs.json`，独立于 SQLite DB，仅存储主题模式：

- **`ThemePrefsCache.read()`** — 从 `getApplicationSupportDirectory()` 下的 `theme_prefs.json` 读取，失败或文件不存在时回退到 `AppThemeMode.light`。不依赖 Drift。
- **`ThemePrefsCache.write()`** — 主题切换成功后将当前值写入缓存文件。

## 启动流程变化

```
之前：main() → DB init → DB query → runApp(正确主题)
之后：main() → 读缓存文件 (~5ms) → runApp(正确主题)
      DB 在 LazyDatabase 内部按需初始化，不阻塞首帧
```

## 缓存文件被删的处理

缓存不是 source of truth（DB 才是）。如果文件被删或损坏：

1. `read()` 返回 `AppThemeMode.light` 作为 fallback
2. 应用正常启动，不会崩溃
3. 用户下次切换主题时 `write()` 自动重建缓存文件
4. 不影响任何功能，只是当次启动可能用默认亮色主题

## 改动

- 新增 `lib/infrastructure/services/theme_prefs_cache.dart`
- `lib/main.dart`：移除 `_loadInitialSettings` 阻塞调用，改为先读缓存、立即 `runApp()`
- `lib/features/workbench/pages/workbench_page.dart`：`toggleThemeMode()` 中 DB 保存成功后加一行 `ThemePrefsCache.write(nextMode)`

## 验证

- 通过 `flutter analyze`。
- 通过 `flutter test`（188 个测试全部通过）。

## 为什么不用于任务列表

本方案解决的是**时序问题**而非性能问题——主题值必须在首帧渲染前拿到，否则会闪烁。任务列表不存在这个约束，首帧后正常显示加载态即可。

将 JSON 缓存模式推广到任务数据反而有害：

1. **缓存一致性** — 任务随时被增删改、重排、进度刷新，缓存极易过期
2. **数据量** — 几十条复杂实体的 JSON 序列化/反序列化不见得比 SQLite 查询快
3. **双写负担** — 每个任务操作都要维护一份 JSON 快照，增加复杂度和出错概率
4. **无收益** — 用户感知不到几十毫秒的加载差异
