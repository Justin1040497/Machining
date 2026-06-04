---
name: framelean-test-plan
description: "Use to write FrameLean project-level feature test plans or test documents from docs/develop/test-plan.md, analysis.md, design.md, tasks.md, current code, and existing tests. Includes automated, manual, platform, build, packaging, and API/service checks; API testing is only a small optional section when a real API surface exists. Use only inside the FrameLean repository."
---

# FrameLean Test Plan

Write the plan for how a FrameLean feature should be tested. This skill drafts or updates a test document; it does not run validation commands. Use `framelean-review` to execute checks.

## Required Context

Read `docs/develop/test-plan.md` first. Then read the feature `analysis.md`, `design.md`, `tasks.md`, relevant current tests under `test/`, and source files touched by the feature.

Preserve the `framelean-workflow` gate: do not add or run implementation tests unless the user explicitly says `可以`.

## Document Location

Use:

```text
docs/features/{module}/{version}/test.md
```

If the feature is split by client/server and both have independent verification, use:

```text
docs/features/{module}/{version}/client/test.md
docs/features/{module}/{version}/server/test.md
```

## Output Shape

Use Chinese.

```markdown
# {功能名} — 测试计划

## 1. 测试目标

## 2. 自动化测试项

| 测试项 | 测试文件/命令 | 覆盖行为 | 备注 |
| --- | --- | --- | --- |

## 3. 手动功能测试项

| 场景 | 操作 | 期望结果 |
| --- | --- | --- |

## 4. 平台 / 构建 / 打包验证

| 平台或产物 | 验证方式 | 期望结果 |
| --- | --- | --- |

## 5. API / 服务端测试项

| 接口或链路 | 请求/步骤 | 期望结果 | 文档产物 |
| --- | --- | --- | --- |

## 6. 不覆盖范围

## 7. 验收标准
```

## Source Selection

- For Dart/Flutter changes, start from `flutter analyze`, `flutter test`, and the affected `test/*.dart` files.
- For domain/application changes, require focused unit tests around entities, use cases, repositories, services, and state transitions.
- For UI/workbench changes, include widget tests and manual checks for visible behavior when automated coverage is insufficient.
- For FFmpeg / FFprobe behavior, include command construction, media analysis, process observation, runtime path, and error handling checks.
- For scripts, packaging, CI, release, or platform runtime changes, include command-level and artifact-layout checks.
- For API/service work, include API chain tests only when a real HTTP/service surface exists or is explicitly part of the accepted design. Do not force API tests onto local-only Flutter features.

## API Section Rule

The original Link Test Writer pattern is adapted here as test-document content, not as the default deliverable. If API checks are relevant, describe the chain, inputs, expected statuses, generated docs, and commands. Create scripts only after the implementation task explicitly calls for them.
