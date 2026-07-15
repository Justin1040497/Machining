---
name: framelean-feature-analysis
description: "Use for FrameLean requirement and existing-feature analysis, product-scope clarification, interaction or state-flow mapping, dependency discovery, and architecture boundary review before planning or implementation. Use only inside the FrameLean repository."
---

# FrameLean Feature Analysis

Read `.agents/skills/README.md` and inspect the smallest set of docs, source, tests, scripts, and configuration that can establish the current behavior.

Produce an evidence-first analysis in Chinese. Adapt the structure to the problem; cover only what helps the decision:

- Current behavior and evidence.
- User-visible flow, feedback, recovery, and acceptance signals.
- Relevant state transitions or event flow.
- Product scope and non-goals.
- Dependencies and FrameLean layer boundaries.
- Options, risks, conflicts between docs and code, and a recommendation.

Use a table, Mermaid flow, or logic tree only when it materially clarifies several relationships. Cite concrete files or symbols for important technical claims. Default to inline output; persist only confirmed version facts, durable decisions, or reusable lessons through the appropriate workflow.

Do not proceed to planning or implementation until the user accepts the analysis or has requested end-to-end execution.
