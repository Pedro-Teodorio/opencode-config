---
name: harness-sdd
description: Govern Harness spec.md, plan.md, tasks.md, human approval, invalidation cascade, stale tasks, build gates, Verify, and Evidence. Use for /spec, /approve, /build, /close, or material changes to approved SDD artifacts.
---

# Harness SDD

This skill defines what is contractual in vault-first SDD. `harness-memory` owns resolved paths and machine-state writes; `obsidian-markdown` may improve human prose but cannot change this contract.

## Required order

When writing SDD in the vault:

1. Load `harness-memory`, discover config, resolve paths, and pass doctor.
2. Apply this skill's skeleton, statuses, sections, gates, Verify, and Evidence rules.
3. Load `obsidian-markdown` only for spec/plan prose, using the restricted conventions below.
4. Write with filesystem tools to the resolved absolute paths.

Never use Obsidian CLI as a required write or retrieval path.

## Status model

- Spec and plan: `draft`, `approved`, `rejected`, `done`, or `superseded`.
- Tasks batch: `todo`, `in_progress`, `blocked`, or `done`.
- Task item: `[ ]` todo, `[x]` done, `[~]` blocked, `[-]` cancelled.
- Agents create and edit drafts. Only a human can authorize `approved` in the current turn through `/approve` or an equivalent explicit request.
- Build does not set spec or plan to `done`; total close does.

## Feature numbering

1. Slugify the requested feature to lowercase ASCII kebab-case; ask if the meaning would change.
2. List immediate directories under resolved `specsDir` matching `[0-9][0-9]-*`.
3. Select one plus the highest numeric prefix, starting at `01`.
4. Before writing, check the target does not exist. On collision, list again rather than overwriting.
5. Create `{specsDir}/NN-slug/` containing exactly `spec.md`, `plan.md`, and `tasks.md`.

## Templates

Use these references as the skeleton:

- [references/spec-template.md](references/spec-template.md)
- [references/plan-template.md](references/plan-template.md)
- [references/tasks-template.md](references/tasks-template.md)

Replace every placeholder. Empty required sections are prohibited; use `N/A - <motivo>` when genuinely inapplicable.

### Spec contract

- Business behavior only: no repository paths, code snippets, class names, function names, or library choices.
- Include problem, expected behavior, out of scope, edge cases, acceptance criteria, and open questions.
- Acceptance criteria must have stable IDs such as `AC-01`; edge cases use `EC-01`.
- Keep `[[plan]]` and `[[tasks]]` navigation.

### Plan contract

- Base it on the current spec and actual repository inspection.
- `## Arquivos` is mandatory and non-empty, with action, exact git-relative path in backticks, and reason.
- Include approach, decisions, implementation order, tests, risks, and exclusions.
- Keep `[[spec]]` and `[[tasks]]`; never wikilink a code path.
- Do not put execution checkboxes in plan.

### Tasks contract

- Create atomic, dependency-ordered tasks with imperative titles.
- Every task has `Status`, `Depends`, `Files`, `Covers`, `Verify`, `Evidence`, and `Notes`.
- `Files` must be a subset of the plan file table unless the plan is explicitly revised first.
- `Verify` is an exact runnable command, not “run tests”.
- Keep tasks plain and machine-readable: no callouts, embeds, or decorative properties.

## Restricted Obsidian prose

- Properties are only those in the templates.
- Allowed callouts: `warning` for risks/atypical, `info` for out of scope, and `question` for open questions.
- Avoid embeds.
- Ideas and ledger may use domain tags plus optional `#harness`.
- Style never overrides frontmatter, status, Evidence, Verify, or active-context shape.

## Approval

Approval always reads source frontmatter; never trust the active-context mirror as authority.

- `all` or empty: approve spec, then plan, only if both files exist and are valid.
- `spec`: approve only spec.
- `plan`: require spec already approved, then approve plan.
- Update `updated` for each changed artifact.
- Set `active-context.plan_approved` to true only when both source statuses are approved.
- If reapproving a stale plan, ask whether to clear stale; default after confirmation is `stale: false`. Do not silently discard stale state.

## Invalidation cascade

Before materially editing an approved spec, or when the human says to invalidate it:

1. Change spec from `approved` to `draft` or the explicitly requested non-approved status.
2. Change plan to `status: draft` and update its date.
3. Set `active-context.plan_approved: false`.
4. Set tasks `stale: true`.
5. Preserve all completed `[x]` tasks under the `soft` policy.
6. Report the cascade and block normal build until explicit reapproval.

A typo or formatting-only change is not material. If unclear, ask one short question before cascading.

## Build gate

At the start of build, read merged gates plus spec and plan frontmatter.

- Normal build fails before any code or state mutation when `requirePlanApproved` is true and either source is not approved.
- A hotfix with a non-empty reason bypasses only the approval gate.
- Hotfix never bypasses task dependencies, Verify, Evidence, security, or review.
- Soft-stale tasks produce a visible warning and require confirmation of the selected task after reapproval.

## Verify and Evidence

When `requireEvidence` is true, a task may become `[x]` only after:

1. Its exact `Verify` command was executed for the current changes.
2. The command exited `0`.
3. `Evidence` records the command, exit code, and concise result, for example: `` `npm test -- auth` - exit 0; 12 passed ``.
4. Covered acceptance/edge IDs remain satisfied.

On failure, keep the task open and record useful notes. Never fabricate Evidence from an earlier run.

## Failure streak and atypical state

- The streak is per `task_id` and counts consecutive non-zero executions of that task's exact Verify.
- Reset to `0` when task changes or becomes `[x]`.
- With `testFailStreakAtypical: 3`, failures 1 through 3 update the streak only; the fourth consecutive failure sets `atypical: true` and records `atypical_reason`.
- Atypical close requires a complete mistake-ledger entry for that feature/task.

## Close

- Partial is the default while any task is pending or blocked. It logs continuity and never marks spec/plan done.
- Total requires approved source spec/plan, all task items `[x]` or `[-]`, valid Verify/Evidence for every `[x]`, and successful `verify.final`; only then does it set spec, plan, and tasks batch to `done`.
- Force total is allowed only with an explicit non-empty reason and session-log `force: true`; it bypasses source approval only, never task Verify/Evidence or final verification.
- If `verify.final` is empty, warn and require explicit human confirmation.
- `recordMistake` persists or reuses the matching ledger entry; the successful close helper writes one final session log and then clears the active atypical gate, preventing duplicate ledger and log entries.
- Use `harness-memory` close helpers; never delete prior specs or logs.
