---
name: framelean-feature-analysis
description: "Use for FrameLean requirement and existing-feature analysis, product-scope clarification, interaction or state-flow mapping, dependency discovery, and architecture boundary review before planning or implementation. Use only inside the FrameLean repository."
---

# FrameLean Feature Analysis

Read `.agents/skills/README.md`, select the target component's pre-read set, and inspect the smallest set of docs, source, tests, scripts, and configuration that can establish the current behavior.

Produce an evidence-first analysis in Chinese. Adapt the structure to the problem; cover only what helps the decision:

- Current behavior and evidence.
- User-visible flow, feedback, recovery, and acceptance signals.
- Relevant state transitions or event flow.
- Product scope and non-goals.
- Dependencies and FrameLean layer boundaries.
- Options, risks, conflicts between docs and code, and a recommendation.

Separate current implementation, confirmed next-stage scope, and long-term architecture. For cross-component work, identify which component owns the user-facing state, in-process processing, process host, server behavior, protocol responsibility, and generated artifacts. Do not infer implemented FEngine communication from its target definition or infer Backend modules from directory names instead of `backend/pom.xml`.

Use a table, Mermaid flow, or logic tree only when it materially clarifies several relationships. Cite concrete files or symbols for important technical claims. Default to inline output; persist only confirmed version facts, durable decisions, or reusable lessons through the appropriate workflow.

Keep external reference-project or competitor research in ignored `.workspace/` material and express tracked conclusions only in FrameLean terms. Do not proceed to planning or implementation until the user accepts the analysis or has requested end-to-end execution.
