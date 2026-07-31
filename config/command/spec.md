---
description: Gera o trio SDD draft no vault resolvido pelo Harness.
---

# /spec

Feature: $ARGUMENTS

1. Carregue, nesta ordem, `harness-memory`, `harness-sdd` e `obsidian-markdown`.
2. Rode o doctor mínimo; sem `vaultPath` ou layout legível, falhe antes de escrever.
3. Se `$ARGUMENTS` estiver vazio ou ambíguo, peça slug e descrição em uma pergunta curta.
4. Atualize active-context via filesystem-first para `mode: spec`, sem sintaxe decorativa.
5. Liste os diretórios imediatos em `specsDir`, calcule o próximo `NN` e confira colisão.
6. Escreva primeiro o contrato de negócio em `spec.md`, usando o template SDD e preenchendo todas as seções.
7. Delegue ao `planner` a inspeção do repo e a produção de `plan.md` e `tasks.md` coerentes com a spec.
8. Grave exatamente `spec.md`, `plan.md` e `tasks.md` em `{specsDir}/NN-slug/`:
   - skeleton, frontmatter, status e campos de máquina vêm de `harness-sdd`;
   - prosa de spec/plan pode usar os wikilinks e callouts permitidos;
   - tasks permanece strict, com Verify e Evidence intactos.
9. Todos os artefatos começam draft/todo. Nunca autoaprove.
10. Reescreva active-context via `harness-memory` com feature, paths absolutos resolvidos, `plan_approved: false` e `must_read` somente em strings relativas `memory:<path>` ou `repo:<path>`.
11. Toda escrita é filesystem-first. Obsidian CLI é opcional e best-effort; indisponibilidade não falha o command.
12. Retorne os três paths e oriente: “revise e use `/approve` quando validar”.
