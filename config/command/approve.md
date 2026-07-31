---
description: Registra aprovação humana de spec e/ou plan do Harness.
---

# /approve

Alvo: $ARGUMENTS

1. Carregue `harness-memory` e `harness-sdd`; resolva a feature ativa e leia os três arquivos via filesystem-first.
2. Interprete vazio ou `all` como spec e plan; `spec` como somente spec; `plan` como somente plan. Recuse outros valores.
3. Esta invocação é autorização humana atual. Nunca aprove se spec/plan não existir, tiver template incompleto ou frontmatter inválido.
4. Para `spec`, altere somente o status da spec para `approved` e `updated` para hoje.
5. Para `plan`, exija spec já `approved`; então altere status e data do plan.
6. Para `all`, aprove spec primeiro e plan depois, em uma operação coerente.
7. Releia as fontes e reescreva `active-context.plan_approved` como `(spec == approved && plan == approved)`; o mirror nunca é a fonte.
8. Se tasks estiver `stale: true` durante reaprovação do plan, pergunte se o humano quer limpar; após confirmação, o default é `stale: false`.
9. Não altere Evidence, marks de tasks ou status `done`.
10. Obsidian CLI é opcional e best-effort. Retorne os status finais de spec, plan, stale e plan_approved.
