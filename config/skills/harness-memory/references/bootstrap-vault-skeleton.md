# Bootstrap Vault Skeleton

Esta e a referencia canonica do skeleton criado pelo `/init-harness`. O fluxo
deve ser `create-if-missing`: criar somente o que estiver ausente e preservar
o que ja existir.

## Regras obrigatorias

1. Resolva o diretorio do produto (`productDir`) e o diretorio de memoria do
   repositorio (`repoMemoryRoot`) antes de operar. Todos os paths abaixo sao
   relativos aos respectivos diretorios resolvidos: `ideas/`, `project-overview.md`
   e `shared-constitution.md` ficam sob `productDir`; `specs/`,
   `memory/session-logs/`, `memory/active-context.md`, `constitution.md`,
   e `mistake-ledger.md` ficam sob `repoMemoryRoot`, conforme o layout da skill.
   A origem para a copia fiel do template e
   `config/skills/harness-memory/references/active-context-template.md` no
   repositorio/skill, fora do vault.
2. Para cada arquivo, verifique se ele existe antes de criar. Arquivos
   humanos existentes devem ser preservados sem sobrescrita, truncamento,
   mesclagem ou substituicao de conteudo.
3. Nao apague, renomeie ou recrie arquivos existentes como parte do bootstrap.
   Uma recriacao so pode ocorrer por um fluxo separado com confirmacao
   explicita; ela nao faz parte deste skeleton.
4. Crie cada diretorio abaixo quando ele estiver ausente. Diretorios existentes
   devem permanecer intactos.
5. O conteudo novo de prosa deve ser um stub minimo: somente o titulo indicado
   e o TODO indicado. Nao tente redigir uma overview, constituicao ou historico
   completo.

## Layout canonico

No diretorio do produto (`productDir`), garanta os seguintes arquivos:

### `project-overview.md`

Stub quando ausente:

```text
# Project Overview

TODO: preencher a visao geral do produto.
```

### `shared-constitution.md`

Stub quando ausente:

```text
# Shared Constitution

TODO: preencher os principios compartilhados do produto.
```

No diretorio de memoria do repositorio (`repoMemoryRoot`), garanta os seguintes arquivos:

### `constitution.md`

Stub quando ausente:

```text
# Repository Constitution

TODO: preencher os principios especificos do repositorio.
```

### `mistake-ledger.md`

Stub quando ausente:

```text
# Mistake Ledger

TODO: registrar incidentes e aprendizados quando existirem.
```

### `memory/active-context.md`

Quando o destino `repoMemoryRoot/memory/active-context.md` no vault estiver
ausente, crie-o copiando fielmente o template estrito de
`config/skills/harness-memory/references/active-context-template.md` no
repositorio/skill. A copia deve preservar exatamente o frontmatter e o corpo
do template, sem adicionar campos, callouts, embeds, comentarios ou prosa. Se o
arquivo de destino ja existir, preserve-o sem
qualquer alteracao.

## Diretorios obrigatorios

Crie quando ausentes, sem remover ou reorganizar conteudo existente. A raiz
canonica de cada diretorio e explicita: `ideas/` e criado sob `productDir`,
enquanto `specs/` e `memory/session-logs/` sao criados sob `repoMemoryRoot`:

- `productDir/ideas/`
- `repoMemoryRoot/specs/`
- `repoMemoryRoot/memory/session-logs/`

Conforme o layout da skill, `memory/active-context.md` fica sob
`repoMemoryRoot`. A origem `config/skills/harness-memory/references/active-context-template.md`
fica no repositorio/skill, fora do vault, e e a referencia de origem do template
estrito; ela nao e um stub humano do vault. Nao invente um template alternativo
nem altere o template de origem durante o bootstrap.

## Resultado esperado

O skeleton esta garantido quando todos os arquivos ausentes foram criados com
os stubs ou a copia estrita indicada, todos os diretorios ausentes foram
criados e nenhum arquivo preexistente foi sobrescrito. A existencia dos itens
nao autoriza declarar inicializacao concluida sem executar o diagnostico
completo do Harness.
