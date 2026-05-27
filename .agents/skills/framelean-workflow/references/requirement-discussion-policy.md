# Requirement Discussion Policy

Use this policy before execution for bug fixes, new features, architecture cleanup, and product direction questions.

## Required Understanding

Before presenting a final solution:

1. Read relevant project docs.
2. Inspect the actual code, tests, scripts, and configuration touched by the request.
3. Search project history or existing patterns with `rg`.
4. When outside practice matters, search official docs and credible professional sources.
5. Classify the request as bug fix, new feature, architecture cleanup, product direction, docs/tooling, release, or hotfix.

## Discussion Stance

- Do not flatter or simply agree with the user.
- State when the user's idea is too narrow, risky, expensive, hard to test, or not how mature products usually solve the problem.
- Offer better alternatives when they exist, including enterprise, market-product, or long-term maintenance options.
- Separate facts from assumptions and speculation.

## Option Shape

For each meaningful option, describe:

- What it changes.
- Strengths.
- Shortcomings.
- Risk and maintenance cost.
- Test strategy.
- Product or user impact.
- When it should not be chosen.

## Gate Rule

Do not start branch setup, tests, or implementation until the user explicitly says `可以`.
