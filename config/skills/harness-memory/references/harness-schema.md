# Harness schema MVP

Merge order: defaults < harness.json < harness.local.json < HARNESS_VAULT_PATH.

## Commit-ready file

```json
{
  "version": 1,
  "product": "meu-produto",
  "repo": "backend",
  "memory": {
    "root": "backend",
    "maxContextFiles": 12,
    "maxContextChars": 24000
  },
  "paths": {
    "productRoot": "01-Projects/meu-produto-plataforma",
    "specs": "specs",
    "ideas": "ideas",
    "activeContext": "memory/active-context.md",
    "sessionLogs": "memory/session-logs",
    "constitution": "constitution.md",
    "sharedConstitution": "shared-constitution.md",
    "mistakeLedger": "mistake-ledger.md",
    "projectOverview": "project-overview.md"
  },
  "gates": {
    "requirePlanApproved": true,
    "requireEvidence": true
  },
  "policies": {
    "staleTasks": "soft",
    "testFailStreakAtypical": 3
  },
  "verify": {
    "final": []
  }
}
```

Required values without defaults: `product`, `repo`, and `paths.productRoot`. `memory.root` defaults to `{repo}` and should be written explicitly by bootstrap. `memory.vaultPath` is required only after merge and must come from `harness.local.json` or the `HARNESS_VAULT_PATH` environment variable.

## Local file

`harness.local.json` is gitignored and stores machine-local values only:

```json
{
  "memory": {
    "vaultPath": "/absolute/path/to/vault"
  }
}
```

## Merge semantics

- Objects merge recursively.
- Arrays and scalar values replace previous values.
- `HARNESS_VAULT_PATH`, when non-empty, overrides `memory.vaultPath` from `harness.local.json`.
- Unknown fields produce a doctor warning; unknown status/frontmatter fields are not propagated into machine contracts.

## Resolved paths

`productDir` joins `vaultPath` and `productRoot`. `repoMemoryRoot` joins `productDir` and `memory.root`, defaulting the latter to `{repo}`. Every other vault path is resolved from one of those roots according to the formulas in the skill.

Paths below the vault are relative. Canonicalize roots and targets, then reject traversal or symlink escape outside `vaultPath`.

`active-context.must_read` uses explicit relative prefixes: `memory:<path>` from `repoMemoryRoot` or `repo:<path>` from `harnessRoot`. Absolute, unprefixed, traversing, missing, and symlink-escaped entries are rejected before read.
