---
name: spec-driven-development
description: >
  Use this skill when working on any Azure DevOps work item — User Story, Task, Bug, Feature, or Epic —
  even if the user just says "start this ticket", "work on #1234", or "build this feature".
  Use it whenever the work requires a plan before coding, design approval, progress tracking across
  sessions, or breaking a large item into subtasks. Do not use for ad-hoc code edits that have no
  associated work item.
---

# Spec-Driven Development

## Setup
For first-time configuration, follow [docs/setup.md](docs/setup.md).

## Configuration
Load `spec-driven-config.md` from the project root before starting. This file contains ADO settings, branch conventions, quality gates, and MCP server name.

## Workflow Checklist
Copy this checklist into your response at the start of each work item:

- [ ] Read `spec-driven-config.md`
- [ ] Read project documentation and rules
- [ ] Check `.spec-driven-progress/` for existing context
- [ ] **Phase 1–4: Planning** — await explicit user approval ✋
- [ ] **Phase 5: Implementation** — await approval before each commit/push ✋
- [ ] **Phase 6: Completion** — verify all PRs merged, close work item

## Phases

### Planning (Phases 1–4)
Follow [reference/planning.md](reference/planning.md).

Deliverables: approved design doc, subtask breakdown, ADO child work items.

> ✋ **STOP after planning — MUST receive explicit "approved" or "proceed" before implementation.**

### Implementation (Phase 5)
Follow [reference/implementation.md](reference/implementation.md).

> ✋ **Always pause and wait for explicit user approval before every `git commit` and `git push`.**

### Completion (Phase 6)
Follow [reference/completion.md](reference/completion.md).

## ADO Operations
See [reference/ado-operations.md](reference/ado-operations.md) for MCP tool examples and Azure CLI alternatives.

## Full Workflow Guide
See [docs/WORKFLOW-GUIDE.md](docs/WORKFLOW-GUIDE.md) for overview, naming conventions, and work item type considerations.

## Critical Rules
1. Always start in PLAN MODE — never code before planning is approved
2. Always pause and wait for explicit user approval before every `git commit` and `git push`
3. Update `.spec-driven-progress/` after every significant step
4. Follow existing patterns — search the codebase before implementing
5. Run builds and tests before committing
