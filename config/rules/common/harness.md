# Harness MVP

Apply this rule when the current repository or an ancestor contains `harness.json`.

## Authority

1. Global rules are the baseline.
2. The resolved `shared-constitution.md` overrides global defaults for the product.
3. The resolved repo `constitution.md` has highest project guardrail priority.
4. The approved spec defines behavior; the approved plan defines implementation scope; tasks define execution order.

## Required skills

- Load `harness-memory` before any Harness operation to discover config, resolve paths, run doctor, and perform vault I/O.
- Load `harness-sdd` for spec, plan, tasks, approve, cascade, build gates, Evidence, and Verify.
- Load `obsidian-markdown` only for human prose in ideas, overview, constitutions, spec/plan bodies, logs, or ledger. It never changes machine contracts.

## Modes

- `discuss`: read-only for product code; may update Markdown memory and active context.
- `spec`: create or edit draft SDD artifacts; do not implement product code.
- `build`: requires the explicit gate check, then executes tasks in dependency order.
- `/init-harness` é o bootstrap e a única exceção Harness permitida antes da existência ou do discovery de `harness.json`; os demais comandos continuam exigindo o discovery normal.

## Approval and gates

- Somente humano pode mudar spec ou plan para `approved`, through `/approve` or an equivalent explicit instruction in the current turn.
- Agents never infer approval from positive language or from `active-context.plan_approved`.
- Normal build refuses unless required spec and plan statuses are both `approved`.
- A hotfix requires a non-empty reason and bypasses only the approval gate.
- A task becomes `[x]` only after its exact Verify succeeds and Evidence is recorded when required.
- Build never marks spec or plan `done`; total close owns that transition.

## Memory and I/O

- Use filesystem-first Read/Write/Edit/Glob/Grep on paths returned by `harness-memory`.
- Never hardcode a vault path in commands or agents.
- Obsidian CLI is optional and best-effort. Its absence or failure cannot block a Harness flow.
- Keep `active-context.md` and tasks machine-readable; do not add decorative callouts, embeds, or properties.
- Apply context file and character budgets before injecting retrieval results.
- Canonicalize every `must_read` target and reject absolute paths, traversal, or symlink escape outside the selected repo or memory root.

## SDD changes

- Material change to an approved spec triggers cascade before editing: plan draft, approval mirror false, tasks soft-stale.
- Soft stale preserves completed task marks but normal build remains blocked until explicit reapproval.
- Spec prose contains no code, libraries, class names, or repository paths.
- Plan code paths use backticks, never wikilinks.

## Session policy

- The fourth consecutive Verify failure on the same task marks it atypical when the configured threshold is `3`.
- An atypical session cannot close until the mistake ledger contains a complete current entry; after logging it, clear the active gate to avoid duplicate entries.
- Partial close preserves approved spec/plan statuses and continuation state.
- Total close requires approved sources, valid Verify/Evidence for every completed task, and final verification. Force total needs a reason, logs `force: true`, and bypasses only source approval.

The MVP is prompt-enforced. Do not claim hard runtime enforcement and do not add a Harness plugin or new agent.
