---
description: Inicializa ou garante a configuracao e o skeleton do Harness com confirmacao humana.
---

# /init-harness

Este e um comando prompt-only. Carregue `harness-memory` e `harness-sdd` e
leia, na skill `harness-memory`, as referencias pertinentes
`references/harness-schema.md`, `references/bootstrap-vault-skeleton.md` e
`references/active-context-template.md`. Use `harness-sdd` somente para o
contrato de bootstrap, estados e gates; nao carregue templates SDD que nao sao
usados por este comando. Siga essas referencias como contrato.
Nao use script, plugin ou runtime auxiliar. Nao interprete nem parseie flags ou
argumentos; se houver texto adicional, trate-o como contexto e faca o fluxo
interativo abaixo.

## Regra de bootstrap e descoberta

Este e o unico comando autorizado a fazer bootstrap sem discovery previo.
Comece no diretorio da invocacao e confirme com o usuario a raiz real do git;
use a raiz retornada pelo git, nao uma pasta presumida. Pare sem escrever se
nao houver uma raiz git valida, se a raiz nao for um diretorio, se ela estiver
fora do escopo confirmado ou se o usuario nao a confirmar.

Antes de qualquer mutacao, inspecione somente o estado necessario, carregue as
skills e referencias acima, confirme que as duas zonas de escrita autorizadas
sao a raiz git confirmada e o vault somente dentro de `productDir` e
`repoMemoryRoot` canonicos validados, e classifique o estado antes do
questionario. Nenhuma escrita pode ocorrer fora dessas raizes autorizadas.

Se `harness.json` valido ja existir, reutilize `product`, `repo`,
`paths.productRoot` e `memory.root` dele, preserve por padrao tudo que for
versionavel e peca somente os dados ausentes. Em especial, peca o vault
absoluto quando ele nao puder ser obtido de `harness.local.json` ou
`HARNESS_VAULT_PATH`, e confirme a criacao do local ausente sem pedir de novo
os valores ja validos. Se o arquivo existir mas for invalido, conflitante ou
exigir destruicao, falhe com remediacao acionavel e nao o substitua
silenciosamente; qualquer recriacao exige o fluxo de confirmacao especifica
abaixo. Se `harness.json` nao existir, faca o questionario completo com estas
seis entradas, nesta ordem:

1. **Raiz do repositorio**: caminho absoluto da raiz git confirmada.
2. **Produto**: nome obrigatorio, nao vazio.
3. **Repo**: identificador do repositorio, sugerido pelo basename da raiz git.
4. **productRoot**: caminho relativo dentro do vault, sugerido pelo
   identificador do produto; mostre tambem o preview absoluto
   `vault/productRoot` depois de receber o vault.
5. **memory.root**: caminho relativo sob o diretorio do produto, sugerido pelo
   valor de `repo`.
6. **Vault**: caminho absoluto do vault.

Nao aceite resposta vazia para produto, repo, productRoot, memory.root ou
vault quando esses dados forem solicitados. Apresente um resumo final com os
valores reutilizados ou informados, os caminhos absolutos de `productDir` e
`repoMemoryRoot`, as duas zonas autorizadas, os arquivos que serao criados e
os arquivos que nao serao tocados. Antes de qualquer mutacao, exija
confirmação explícita do resumo final e de que nenhuma escrita ocorrera fora
da raiz git confirmada, de `productDir` e de `repoMemoryRoot` canonicos
validados. Cancelamento, resposta ambigua ou recusa encerra sem escrita.

## Validacao de seguranca

Valide todos os valores antes da confirmação e novamente imediatamente antes
da escrita:

- `productRoot` e `memory.root` devem ser relativos, normalizados, nao vazios,
  sem raiz de filesystem, sem separador inicial, sem `..` ou componente de
  traversal, e sem normalizacao que escape de sua raiz.
- `repo` deve ser um identificador relativo seguro, sem `/`, `\\`, `..` ou
  componente oculto de traversal. O basename sugerido pode ser ajustado pelo
  usuario, mas deve continuar seguro.
- O vault deve existir, ser acessivel e ser um diretorio. Resolva o caminho
  canonico e valide containment: `productDir` deve permanecer dentro do vault
  e `repoMemoryRoot` dentro de `productDir`.
- A raiz git confirmada e o vault sao zonas distintas: arquivos de configuracao
  ficam somente na raiz git; o skeleton fica somente em `productDir` e
  `repoMemoryRoot`. Nenhum destino pode ser inferido como relativo ao diretorio
  de execucao ou ao repositorio quando pertencer ao vault.
- Canonicalize cada raiz e destino e rejeite symlink ou componente de caminho
  que escape da raiz permitida. Para destinos ainda ausentes, valide todos os
  ancestrais existentes e a containment esperada antes de criar diretorios.
- Rejeite caminhos absolutos, traversal, symlink escapando, vault inacessivel,
  conflito de arquivo/diretorio e qualquer ambiguidade. Nao tente contornar a
  validacao nem crie fora das raizes canonicas.

## HARNESS_VAULT_PATH e arquivos do repositorio

Se `HARNESS_VAULT_PATH` estiver definido e nao vazio, mostre o valor recebido,
explique que ele sobrescreve o vault respondido no questionario e peça
confirmação explícita do override. O valor efetivo passa a ser o override,
depois das mesmas validacoes de acessibilidade, containment, traversal e
symlink. Mesmo nesse caso, persista `harness.local.json` na raiz do repositorio
com somente `memory.vaultPath`, isto e, somente o `vaultPath` absoluto efetivo.
Nunca persista `memory.vaultPath` em `harness.json`.

Crie ou garanta `harness.json` como JSON commit-ready conforme
`harness-memory: references/harness-schema.md`: preserve configuracoes existentes validas, mantenha
`memory.root` explicito e nao inclua `memory.vaultPath`. Se o arquivo existente
for invalido, conflitante ou exigir destruição, falhe com remediacao acionavel;
nao o substitua silenciosamente.

Crie ou garanta `harness.local.json` somente com `memory.vaultPath`, sem
qualquer outra chave, e o caminho absoluto efetivo. Um local ausente pode ser
criado. Um local valido existente deve ser preservado sem clobber; um local
incompleto ou com chaves extras deve ser reportado como incompleto e nao ser
reescrito implicitamente.
Recriacao ou correcao destrutiva de arquivo existente exige confirmação
explícita separada, imediatamente antes dessa mutacao, e nunca pode apagar
prosa humana.

Garanta `.gitignore` na raiz git sem remover nem reordenar entradas existentes:
adicione `harness.local.json` somente se a entrada ainda nao existir, sem
duplicar a entrada. Se a regra ja existir, nao escreva o arquivo.

## Skeleton do vault e estados

Use fielmente `harness-memory: references/bootstrap-vault-skeleton.md`. O fluxo
e `create-if-missing`: crie apenas diretorios e arquivos ausentes, preserve
cada arquivo preexistente sem sobrescrever, truncar, mesclar, renomear ou
substituir. Para `memory/active-context.md` ausente, copie fielmente
`harness-memory: references/active-context-template.md`, sem adicionar campos,
callouts, embeds, comentarios ou prosa. Nao sobrescreva e nao permita que
qualquer etapa nao confirmada substitua arquivos; não sobrescreva prosa humana
existente.

Diferencie e anuncie o estado antes da confirmacao e antes de qualquer escrita:

- **primeira inicializacao**: `harness.json` nao existe; apos o questionario,
  proponha somente a configuracao e os itens do skeleton ausentes;
- **ensure sem clobber**: `harness.json` valido existe, mas falta local,
  `.gitignore`, diretorio ou arquivo do skeleton; complete somente os itens
  ausentes e reutilize product/repo/productRoot/memory.root;
- **local/skeleton incompletos**: liste cada ausencia, conflito ou item
  ilegivel e proponha a correcao nao destrutiva possivel;
- **recriacao explícita**: nunca regrave arquivo existente por padrao; somente
  prossiga com confirmação explícita especifica para cada arquivo e explique o
  risco. Recriacao nao e parte do ensure;
- **já inicializado/no-op**: tudo ja esta completo e valido; nao escreva nada,
  mas ainda execute o doctor completo;
- **cancelamento**: qualquer cancelamento antes ou durante o fluxo resulta em
  nenhuma escrita e nenhuma mensagem de sucesso.

Nao declare inicializacao concluida pela mera existencia dos arquivos. Falha
de leitura, escrita, parse, permissao, validacao ou doctor deve ser uma falha
acionavel, com caminho, causa e proxima remediacao; nao mostre sucesso parcial.

## Doctor obrigatorio e resumo final

Depois de todas as mutacoes autorizadas (ou no-op), execute o doctor completo de
`harness-memory`, filesystem-first, na ordem D01 a D09. Crie
`memory/active-context.md` a partir do template somente se estiver ausente e
se o parent existir, conforme a referencia; preserve-o se existir. Verifique
que `constitution.md` e `shared-constitution.md` existem e sao legiveis e
que gates e policies mesclados sao validos.

A saida deve conter uma linha estavel para cada check:

```text
DOCTOR: PASS
[PASS] D01 harness.json parsed
[PASS] D02 schema version 1
[PASS] D03 product and repo
[PASS] D04 vaultPath directory
[PASS] D05 productDir directory
[PASS] D06 repoMemoryRoot directory
[PASS] D07 active-context
[PASS] D08 constitutions readable
[PASS] D09 merged gates and policies
```

So declare sucesso somente se todos os D01 a D09 passarem e a saida incluir
`DOCTOR: PASS`. Em qualquer falha, a saida deve incluir `DOCTOR: FAIL`, o check
afetado, o caminho esperado e remediacao acionavel, sem mensagem de sucesso.
Ao concluir, retorne um resumo final explícito contendo estado
(inicializacao, ensure ou já inicializado/no-op), caminhos absolutos,
arquivos criados ou preservados, override do vault quando aplicavel, resultado
de cada D01-D09 e a confirmacao de que nao houve escrita fora das duas zonas
autorizadas: a raiz git confirmada e o vault restrito a `productDir` e
`repoMemoryRoot` canonicos validados.
