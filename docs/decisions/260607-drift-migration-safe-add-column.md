# Drift 新增列迁移使用幂等 helper

## 状态

有效

## 决策

Drift schema 迁移中，新增列统一通过 `AppDatabase._safeAddColumn` 执行。遇到列已存在的 duplicate column 错误时安全跳过，不直接让应用启动失败。

## 原因

Drift `onCreate` 会创建当前完整表结构。开发阶段反复打包、迁移或数据库处于边缘状态时，`onUpgrade` 中的 `ALTER TABLE ADD COLUMN` 可能尝试添加已经存在的列，导致 `SqliteException: duplicate column name`。

## 收益

- 新增列迁移对开发阶段和边缘状态更稳。
- 不改变正常升级路径。
- 后续 schema 变更有统一约束，减少散落迁移代码。

## 约束

- 新增非空列仍必须提供 Drift 默认值或明确迁移填充值。
- 幂等 helper 只处理“列已存在”这类安全重复，不吞掉其他迁移错误。

## 关联

- `docs/develop/data-model.md`
- `docs/lessons.md`
