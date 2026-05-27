# Implementation Policy

Use this policy before editing production code, tests, scripts, or docs.

## Scope

- Implement only the confirmed requirement and test design.
- Do not add unrelated features, broad refactors, visual redesigns, generated artifacts, or formatting churn.
- If the confirmed design becomes impossible or risky, stop and explain the conflict before changing scope.

## Architecture

Follow the current FrameLean structure:

```text
features -> application -> domain
                  |
                  v
            infrastructure
```

Rules:

- `domain` stays independent of Flutter, Drift, FFmpeg, and filesystem details.
- `application` owns use cases, repository interfaces, service abstractions, and workflow orchestration.
- `infrastructure` implements Drift, FFmpeg, FFprobe, filesystem, process, and platform concerns.
- `features` coordinates UI state through Riverpod notifiers and application use cases.
- `app` remains application shell, theme, and routing.

## Code Shape

- Match existing naming, file organization, and error-handling patterns.
- Prefer existing helpers before adding new abstractions.
- Add abstractions only when they remove real duplication, preserve a boundary, or match an established local pattern.
- Avoid 800+ line files when responsibilities can be split; allow large files only for cohesive generated, framework, or strongly coupled library code.
- Keep comments rare and useful.

## After Implementation

Summarize:

- What changed.
- Which confirmed tests or boundaries it satisfies.
- What did not change.
- Any unclear product or business boundary.

Do not continue to validation until the user explicitly says `可以`.
