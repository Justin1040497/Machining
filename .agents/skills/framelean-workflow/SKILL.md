---
name: framelean-workflow
description: "Lightweight router for FrameLean project-level skills. Use when the user is unsure which FrameLean skill to use, asks for an end-to-end workflow, or requests work spanning analysis, planning, implementation, validation, delivery, release documentation, or project skill maintenance."
---

# FrameLean Workflow Router

Read `.agents/skills/README.md`, choose the smallest matching Skill, then load only that Skill and the evidence needed for the request.

## Routing

- Analyze requirements or existing behavior: `framelean-feature-analysis`.
- Compare designs and produce an implementation plan: `framelean-feature-plan`.
- Implement confirmed changes: `framelean-implementation`.
- Review changes or run checks: `framelean-validation`.
- Calibrate affected facts and prepare commit / PR copy: `framelean-delivery`.
- Produce release notes for a specified version: `framelean-release`.
- Create, merge, delete, or refactor project Skills: `framelean-skill-create`.

Only run the full analysis → plan → implementation → validation → delivery chain when the user requests end-to-end execution. Release documentation remains a separate flow.

Do not cross a discussion or planning gate without user acceptance unless the user already requested implementation or full execution. Do not stage, commit, push, tag, open a PR, or publish without explicit authorization.
