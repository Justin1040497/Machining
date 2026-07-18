---
name: framelean-validation
description: "Use for FrameLean validation planning, diff review, targeted or broad check execution, failure diagnosis, and re-validation after implementation. Reviews scope, architecture, tests, docs, packaging, and user-change preservation. Use only inside the FrameLean repository."
---

# FrameLean Validation

Read `.agents/skills/README.md` and the target component's pre-read set. Inspect Git status and the relevant diff before selecting checks; include untracked files when the Monorepo migration or an unstaged change means ordinary diff is incomplete.

Review for scope creep, architecture violations, missing behavior coverage, stale facts, broken runtime or platform assumptions, and unrelated user changes. Run targeted checks first, then broaden according to risk.

For Desktop Client changes, run commands from `desktop-client/`. Check changed Dart formatting without modifying files:

```bash
dart format --output=none --set-exit-if-changed <changed-dart-files>
flutter analyze
flutter test <targeted-tests>
```

Run the full Flutter suite only when the changed surface or requested confidence justifies it.

For Backend changes, select only the affected surface, then broaden when risk requires it:

```bash
cd backend
mvn -B -DskipTests package
docker compose config --quiet

cd admin-web
npm ci
npm run build:prod
```

Use the actual `backend/pom.xml` module list. Do not treat `admin-web` as a root project or replace `npm ci` with dependency upgrades. Run targeted Java or frontend tests when changed behavior has an established test entry.

For FLL or FEngine, run checks from the affected Cargo project rather than assuming one shared workspace.

FLL:

```bash
cd fll
cargo fmt --all -- --check
cargo check --workspace --all-targets --locked
cargo test --workspace --locked
cargo clippy --workspace --all-targets --locked -- -D warnings
cargo tree --workspace
```

FEngine:

```bash
cd fengine
cargo fmt --all -- --check
cargo check --all-targets --locked
cargo test --locked
cargo clippy --all-targets --locked -- -D warnings
cargo tree
```

When FLL Runtime Schema types or exporters change, run `cargo run -p framelean-runtime --example export_schemas --locked` from `fll/`, execute the consistency tests, then compare `fll/schemas/` byte-for-byte. Do not move generated schemas into `protocol/`.

For repository layout, shared paths, CI, or migration-boundary changes, run `scripts/verify/structure.sh` and inspect the relevant workflow or script syntax. Do not execute third-party download/build scripts unless explicitly required.

Review Cargo cycles, crate responsibility drift, CLI/Runtime boundary violations, Pipeline/Plugin reverse dependencies, platform assumptions, and stale paths. Never add unused direct dependencies or empty modules to satisfy a target layout.

For docs or project Skills:

```bash
git diff --check
python3 <current-skill-creator>/scripts/quick_validate.py .agents/skills/framelean-skill-name
```

Resolve the available system `skill-creator` from the current environment; do not embed a user-specific absolute path. If its Python validator cannot import YAML, use another structured YAML parser and report the fallback. Scan for stale paths and deleted names with `rg`.

For tracked and untracked documentation, verify local relative links directly and scan uploadable paths for prohibited external reference-project or competitor terms without listing those terms in tracked files. Confirm ignored `.workspace/` research stays untracked. `git diff --check` does not validate untracked files, so inspect them separately.

Record whether `flutter pub get`, `npm ci`, Cargo, or Maven resolved or downloaded dependencies. Report the checked scope, commands and concrete results, actionable findings, and risks not covered. Never claim a check passed unless it ran successfully, and never modify product logic, dependencies, tests, assertions, or gates merely to obtain a green result.
