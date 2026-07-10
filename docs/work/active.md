# 当前任务

## 维护规则

- 只记录当前正在推进的事项，保持 1 页以内。
- 每个事项必须有下一步，不记录模糊愿望。
- 完成后将结果写入 `CHANGELOG.md`、`docs/releases/`、`docs/lessons.md` 或 `docs/decisions/` 中合适的位置，然后从这里移除。

## 进行中

### v1.2.1 Release 与交付收口

- 当前状态：根仓库与独立 `server` 仓库正在统一为外部下载地址优先策略；package 自更新链继续保留但不再作为默认发布门禁。
- 下一步：确认 `v1.2.1` Release 草稿，写回正式 release 文档，完成文档 diff、发布脚本、Flutter 和 server 定向验证并输出 Commit / PR 文案。
