---
name: framelean-workflow
description: "Lightweight router for FrameLean project-level skills. Use when the user is unsure which FrameLean skill to use, asks for an end-to-end workflow, or requests work spanning analysis, planning, implementation, validation, delivery, release documentation, user changelogs, or project skill maintenance."
---

# FrameLean Workflow Router

Read `.agents/skills/README.md`, identify the target component, choose the smallest matching stage Skill, then load only the relevant component pre-read set, optional domain Skill, and evidence needed for the request.

## Routing

- Analyze requirements or existing behavior: `framelean-feature-analysis`.
- Compare designs and produce an implementation plan: `framelean-feature-plan`.
- Implement confirmed changes: `framelean-implementation`.
- Review changes or run checks: `framelean-validation`.
- Calibrate affected facts and prepare commit / PR copy: `framelean-delivery`.
- Produce release notes for a specified component and version: `framelean-release`.
- Produce a friendly Desktop Client changelog for the current or a specified app version and save it to Downloads: `framelean-user-changelog`.
- Create, merge, delete, or refactor project Skills: `framelean-skill-create`.
- Add `framelean-engine-architecture` when work touches FLL/FEngine ownership, Cargo DAG, Runtime composition, process boundaries, or protocol ownership.
- Add `framelean-media-pipeline` when work touches media stages, Processor, Pipeline, Plugin, analysis, native FFmpeg adapters, or execution readiness.

Do not load Engine domain Skills for unrelated Desktop UI or Backend-only work. Only run the full analysis → plan → implementation → validation → delivery chain when the user requests end-to-end execution. Formal component release documentation and Desktop Client user changelogs remain separate flows.

Do not cross a discussion or planning gate without user acceptance unless the user already requested implementation or full execution. Do not stage, commit, push, tag, open a PR, or publish without explicit authorization.
