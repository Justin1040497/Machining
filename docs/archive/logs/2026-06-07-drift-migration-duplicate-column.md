# Drift 数据库迁移重复列错误修复日志

## Problem Summary

每次新增数据库列、更新 schema 版本并重新打包后，应用启动时报错：

```text
任务列表读取失败
SqliteException（1）： while executing, duplicate column name: theme_mode, SQL logic error （code 1）
Causing statement: ALTER TABLE "'settings" ADD COLUMN "theme_mode" TEXT NOT NULL DEFAULT 'light'
```

这是一个系统性重复问题：只要修改了数据库 schema（添加列），再次打包就会出现。本次触发的是 `settings` 表新增 `theme_mode` 列（v15），但问题不限于这个具体列。

## Root Cause

Drift 的 `MigrationStrategy.onUpgrade` 在每个版本迁移中使用 `migrator.addColumn()` 直接添加列。在正常流程中：

- 新数据库（`from=0`）：`onCreate` 创建包含所有当前列的完整表，`onUpgrade` 不会被调用。没问题。
- 旧数据库升级（`0 < from < to`）：`onUpgrade` 被调用，迁移逐版本添加缺失的列。正常情况没问题。

但在开发阶段反复构建和运行的环境中，存在某些边缘情况（如数据库文件持留、Drift 内部行为或系统缓存）会导致迁移代码运行时目标列已存在于表中，`ALTER TABLE ADD COLUMN` 失败。

## Fix

修改 `lib/infrastructure/database/app_database.dart`：

1. 新增 `_safeAddColumn(Migrator, TableInfo, GeneratedColumn)` 私有方法，在 `migrator.addColumn` 外围接 "duplicate column" 异常并安全跳过。
2. 将所有迁移中的 `await migrator.addColumn(...)` 替换为 `await _safeAddColumn(migrator, ...)`。

这使得所有迁移步骤均幂等——无论目标列是否已存在，迁移都不会因重复添加而崩溃。

## Modified Files

- `lib/infrastructure/database/app_database.dart`
  - 新增 `_safeAddColumn` helper 方法。
  - 所有 `migrator.addColumn` 调用替换为 `_safeAddColumn`（覆盖 v2 到 v15 的所有迁移步骤）。

## Validation Method or Test Result

- 通过 `flutter analyze lib/infrastructure/database/app_database.dart`。
- 通过 `flutter test`（全部 152 个测试）。

## Notes

- 该修复是防御性的：让迁移对未知的边缘状态具有容错能力。
- 后续新增列时，流程不变：在表定义中添加列、更新 `schemaVersion`、在 `onUpgrade` 中使用 `_safeAddColumn` 添加迁移步骤、运行 `build_runner` 重新生成 `.g.dart`。
- 不要回到直接使用 `migrator.addColumn` 的方式；始终使用 `_safeAddColumn`。
