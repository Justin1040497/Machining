# Commit Policy

Use Conventional Commits style that matches `docs/develop/git-workflow.md`.

## Format

```text
<type>(optional-scope): <中文摘要>
```

Use English type and optional English scope. Use Chinese after the colon.

## Types

- `feat`: user-visible feature.
- `fix`: bug fix.
- `docs`: documentation.
- `refactor`: internal code restructuring without intended behavior change.
- `test`: tests only.
- `chore`: tooling, repo maintenance, generated metadata, or housekeeping.
- `build`: build system or dependency changes.
- `ci`: CI configuration.

## Examples

```text
feat(workbench): 添加批量压缩导入入口
fix(ffmpeg): 修复内置运行时路径解析失败
refactor(domain): 拆分压缩策略模型
docs(workflow): 更新项目级执行流程
test(queue): 补充任务暂停恢复回归测试
```

## Splitting Rules

- Split commits by logical behavior or project boundary.
- Keep broad formatting separate.
- Do not mix generated files with manual source edits unless generation is the point of the commit.
- Do not include unrelated user edits.
- Include the matching changelog entry in the same commit as the change.
- For bug fixes, include the matching archive log in the same commit as the fix.

## Commit Body

Add a body when the change has non-obvious motivation, migration risk, compatibility impact, or test notes.
