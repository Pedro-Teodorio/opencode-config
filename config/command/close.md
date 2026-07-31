---
description: Fecha uma sessão Harness parcial ou totalmente e persiste memória.
---

# /close

Tipo: $ARGUMENTS

1. Carregue `harness-memory` e `harness-sdd`; resolva paths e leia active-context e SDD via filesystem-first.
2. Interprete vazio ou `auto` como partial quando houver `[ ]`/`[~]`, caso contrário total. Aceite `partial`, `total`, `total --force <reason>` e `force total <reason>`; force sem reason útil é inválido.
3. Antes de mutar, responda `GATE_CHECK: pass - close=<tipo>` ou `GATE_CHECK: fail - <motivo>`.
4. Se `atypical: true`, qualquer close falha até `recordMistake` encontrar ou adicionar e confirmar uma entry completa da feature/task atual no `mistake-ledger.md`. Esse helper não grava session-log nem limpa estado; ele retorna a flag para o helper final.
5. Em partial, execute `closePartial`: faça um único append no session-log com a flag atypical retornada, limpe o gate reconhecido, preserve spec/plan, grave continuity e deixe active-context idle apontando para a próxima task.
6. Em total normal, releia as fontes e exija spec e plan `approved`. Se uma fonte não estiver aprovada, recuse, exceto em force total explícito com reason; nesse caso audite `force: true` e reason.
7. Exija todos os items `[x]` ou `[-]`. Para cada task `[x]`, valide Verify exato e, quando `requireEvidence` estiver ativo, Evidence com o mesmo comando, `exit 0` e resumo. Force não bypassa esse gate.
8. Rode cada comando de `verify.final`; exit não zero bloqueia done. Se a lista estiver vazia, avise e obtenha confirmação humana explícita.
9. Em total válido, execute `closeTotal`: spec, plan e lote tasks ficam `done`; faça um único append no log somente após todos os gates passarem; active-context volta ao template idle com flags limpas.
10. Nunca apague specs, Evidence, ledger ou session logs anteriores.
11. Ledger e log podem usar tags/callouts leves quando úteis; active-context permanece estrito.
12. Obsidian CLI é opcional e best-effort; falha nunca bloqueia o fechamento.
