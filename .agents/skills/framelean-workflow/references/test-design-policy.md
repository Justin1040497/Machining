# Test Design Policy

Design tests before implementation whenever code behavior changes.

## Select The Test Type

- Bug fix: write or describe a failing reproduction and a regression test.
- New feature: cover domain/application behavior first, then UI/widget or integration behavior when the feature crosses layers.
- Architecture cleanup: protect existing behavior with focused tests before moving code.
- Product direction: define validation criteria, user scenarios, or prototype checks before implementation.
- Scripts, build, and release changes: include command-level validation and artifact checks.

## FrameLean Test Surfaces

Use the actual project layout and `docs/develop/test-plan.md`.

Common surfaces:

- Domain entities and value objects.
- Application use cases.
- FFmpeg planning and command construction.
- Infrastructure mappers, repositories, runtime location, and process handling.
- Workbench notifiers, dialogs, widgets, and file reveal behavior.
- Packaging scripts and platform runtime layout.

## Test Design Output

Before writing tests, summarize:

- Behavior being protected.
- Test files to add or update.
- Important edge cases.
- What is intentionally out of scope.
- Manual checks, if automated coverage is not enough.

## Gate Rule

Do not write tests or implementation until the user explicitly says `可以`.
