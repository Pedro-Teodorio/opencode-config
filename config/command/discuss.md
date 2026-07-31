---
description: Modo discussão Harness sem editar código; pode registrar ideias no vault.
agent: discussion
---

# /discuss

Tema: $ARGUMENTS

1. Carregue `harness-memory`; se houver `harness.json`, faça discovery, resolve e doctor light.
2. Carregue `obsidian-markdown` para prosa de ideas, overview e constitutions, subordinada ao contrato Harness.
3. Atualize active-context via filesystem-first para `mode: discuss`; não embeleze o arquivo de máquina.
4. Leia project overview e shared constitution nos paths resolvidos. Leia código somente para obter contexto.
5. Não edite código, configuração executável ou SDD aprovado.
6. Quando o usuário pedir documentação, liste via filesystem `ideas/YYYY-MM-DD-*.md`, incremente a sequência diária e crie `ideas/YYYY-MM-DD-NN-slug.md`.
7. Use somente properties leves, tags de domínio e wikilinks úteis. Não crie embeds.
8. Obsidian CLI é opcional e best-effort para abrir a nota; falha não altera o resultado.
9. Termine com decisões, alternativas descartadas, riscos, open questions e o handoff “pronto para `/spec`?”.
10. Nunca aprove ou conclua spec, plan ou tasks.
