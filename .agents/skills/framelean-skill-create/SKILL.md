---
name: framelean-skill-create
description: "Use to create, update, merge, delete, or refactor FrameLean project-level skills. Applies the available system skill-creator guidance while keeping project skills under .agents/skills, using the framelean prefix, updating routing docs, and avoiding user-level skill changes unless explicitly requested."
---

# FrameLean Skill Create

Before substantial work, read the available system `skill-creator` completely and follow its concise instruction, progressive disclosure, resource, initialization, metadata, and validation rules.

## Project Rules

- Read `.agents/skills/README.md`, inspect the complete current project-Skill inventory, and compare affected capabilities with the real component manifests, docs, scripts, and source before editing.
- Keep project Skills in `.agents/skills/framelean-*` unless the user explicitly requests a user-level Skill.
- Use lowercase hyphen-case names and YAML frontmatter containing only `name` and `description`.
- Do not create skill-level README, CHANGELOG, installation, or process-note files.
- Add bundled scripts, references, or assets only when repeated execution genuinely needs them.
- After structural changes, update `.agents/skills/README.md`, `framelean-workflow/SKILL.md`, and any existing `agents/openai.yaml` metadata.
- Remove stale names and paths with `rg` while preserving unrelated customization.
- Keep reusable current facts concise and component-aware; do not duplicate large project documentation inside Skills.
- Never place external reference-project or competitor brands in project Skills or their uploadable resources. Keep research under ignored `.workspace/` only.

For new Skills, use the current system `skill-creator` initialization script rather than hand-building the directory. After changes, run its `quick_validate.py` against every affected Skill. Resolve tool locations from the current environment instead of storing personal absolute paths; if Python YAML support is unavailable, validate with another structured YAML parser and report the fallback.
