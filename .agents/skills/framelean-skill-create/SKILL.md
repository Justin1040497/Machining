---
name: framelean-skill-create
description: "Use to create, update, merge, delete, or refactor FrameLean project-level skills. Applies the system skill-creator guidance while enforcing FrameLean-specific rules: project skills live under .agents/skills, names use the framelean prefix, routing docs stay current, and no user-level skill is created unless explicitly requested."
---

# FrameLean Skill Create

Create or update FrameLean project-level skills using the system `skill-creator` guidance plus project rules.

## Required System Skill

Read the system skill creator before substantial work:

```text
/Users/leftzhou/.codex/skills/.system/skill-creator/SKILL.md
```

Use its principles: concise instructions, progressive disclosure, no unnecessary files, validation with `quick_validate.py`, and `init_skill.py` for new skills.

## FrameLean Rules

- Project-level skills live only in `.agents/skills/` unless the user explicitly asks for a user-level skill.
- Skill names must be lowercase hyphen-case and start with `framelean-`.
- Do not create skill-level `README.md`, `CHANGELOG.md`, install guides, or process notes.
- Create bundled `scripts/`, `references/`, or `assets/` only when the skill truly needs them.
- Update `.agents/skills/README.md` and `.agents/skills/framelean-workflow/SKILL.md` after adding, deleting, merging, or renaming skills.
- Update `agents/openai.yaml` when present so UI metadata matches `SKILL.md`.
- Remove stale old skill references with `rg`.

## Creation Workflow

For a new skill, run:

```bash
python3 /Users/leftzhou/.codex/skills/.system/skill-creator/scripts/init_skill.py framelean-skill-name --path .agents/skills
```

Then replace the generated placeholder content with concise project-specific instructions.

## Validation

Run:

```bash
python3 /Users/leftzhou/.codex/skills/.system/skill-creator/scripts/quick_validate.py .agents/skills/framelean-skill-name
```

If the script cannot import Python `yaml`, use Ruby standard-library `YAML` or another structured YAML parser to validate the same frontmatter constraints, and report that fallback. For broad skill restructures, validate every `framelean-*` skill and run stale-reference scans for deleted names.
