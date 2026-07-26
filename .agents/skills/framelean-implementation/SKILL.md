---
name: framelean-implementation
description: "Use to implement confirmed FrameLean changes in production code, tests, scripts, documentation, or project-level skills while preserving scope, architecture, user changes, and project style. Use after requirements are accepted or when the user explicitly requests execution. Use only inside the FrameLean repository."
---

# FrameLean Implementation

Read `.agents/skills/README.md`, the target component's pre-read set, and the accepted requirement or plan. Inspect related implementation and tests before editing.

## Rules

- Make the smallest coherent change that completes the confirmed scope.
- Preserve unrelated user changes and avoid formatting churn, duplicate abstractions, speculative features, and unnecessary dependencies.
- Prefer existing helpers, providers, use cases, mappers, widgets, scripts, and documentation patterns.
- Keep `domain` independent of Flutter, Drift, FFmpeg, filesystem, and platform APIs; keep orchestration in `application`, implementations in `infrastructure`, UI coordination in `features`, and composition / shared presentation in `app`.
- Preserve Backend's actual Maven modules, artifacts, parents, and nested layout. Modify `admin-web` independently when server modules are not involved; do not create or merge `ruoyi-*` modules to match a desired directory shape.
- Treat FLL as the core processing library and FEngine as the independent engine process and process-host boundary. Preserve the Cargo DAG: keep Pipeline and Plugin independent and compose them through FLL Runtime. FEngine must not bypass FLL ownership of Task state, Registry, Factory, Processor, Pipeline, in-process Scheduler, Snapshot, or Schema. Add process lifecycle, communication, supervision, session, or external request modules to FEngine only when real implementation requirements and code exist; never create placeholders.
- Keep implemented protocol v1 wire fields and transport owned by `fengine/src/protocol.rs`, with `protocol/v1` documenting responsibility and compatibility. Keep FLL payload types, Runtime Schema source, exporters, and checked-in baselines in FLL; do not duplicate them under `protocol/`.
- Keep third-party source, licenses, and build inputs under `dependencies/`; keep generated binaries under ignored `build/dependencies/`. Do not download, upgrade, patch, or relink third-party dependencies unless explicitly in scope.
- Update only documentation whose current facts changed. Keep temporary plans in `.workspace/`.
- Never place external reference-project or competitor brands in uploadable files; retain any required research only under ignored `.workspace/` without tracked links.
- If evidence invalidates the agreed scope or exposes a material risk, stop and explain before expanding the task.

After editing, inspect the diff and run proportionate checks for the changed surface. Use `framelean-validation` for deep review, broad suites, or validation-specific work.

Report what changed, the boundary it satisfies, relevant behavior deliberately left unchanged, checks run, and remaining risks.
