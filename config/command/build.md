---
description: Executa tasks do Harness com gate de aprovação, TDD, Verify e Evidence.
---

# /build

Argumentos: $ARGUMENTS

1. Carregue `harness-memory` e `harness-sdd`. Use filesystem-first para estado e retrieval; Obsidian CLI é somente best-effort e nunca participa do gate.
2. Parseie task ID opcional e `--hotfix <reason>` ou `hotfix <reason>`. Reason deve conter texto útil, não apenas a flag.
3. Antes de qualquer mutação ou edição de código, leia config merged e os status fonte. A primeira linha da resposta deve ser uma destas:

```text
GATE_CHECK: pass - spec=approved; plan=approved; hotfix=false
GATE_CHECK: fail - <motivo e correção>
```

4. Recuse build normal quando `requirePlanApproved` for true e spec ou plan não estiver `approved`. Recuse hotfix sem reason. Em falha, não altere código nem active-context.
5. Hotfix válido bypassa somente aprovação. Registre `hotfix: true`, reason e append imediato no session-log. Verify, Evidence, dependências, segurança e review continuam obrigatórios.
6. Com gate pass, selecione a task pedida ou a primeira `[ ]` cujas dependências estejam `[x]`/`[-]`. Avise sobre stale soft e confirme a task se necessário.
7. Reescreva active-context strict com mode build, status in_progress, feature, task_id, tags, paths e mirror calculado das fontes. Em `must_read`, aceite somente strings relativas `memory:<path>` ou `repo:<path>` validadas por containment; ao trocar task, zere `test_fail_streak`.
8. Monte context pack dentro dos budgets: must_read, spec/plan/task, shared constitution, repo constitution e matches relevantes do ledger via Grep/Read.
9. Delegue uma task por vez ao `tdd-guide`, limitado aos `Files` da task e seguindo Red-Green-Refactor.
10. Execute o `Verify` exato. Exit não zero mantém `[ ]`, incrementa `test_fail_streak`; se o novo valor exceder `testFailStreakAtypical`, marque atypical e reason. Com threshold 3, isso ocorre na quarta falha consecutiva.
11. Exit zero só permite `[x]` depois de preencher `Evidence` com comando, exit code e resumo. Ao concluir, zere o streak.
12. Após qualquer mudança de código, delegue ao `code-reviewer`; corrija findings bloqueantes e rode Verify novamente se o código mudar.
13. Nunca marque spec ou plan `done`. Isso pertence ao close total.
