# Instalador da configuração do OpenCode

Este repositório é a fonte da verdade da configuração do OpenCode. A CLI
projeta os arquivos canônicos no destino do usuário com um link simbólico por
arquivo; os diretórios contêineres continuam sendo diretórios reais. Alterações
na árvore `config/` ficam disponíveis imediatamente no destino instalado.

## Requisitos e limites

- Linux; outros sistemas são recusados pela CLI.
- Bash com suporte a arrays nomeados (Bash 4.3 ou mais recente) e utilitários
  POSIX/GNU normalmente disponíveis em uma instalação Linux, incluindo
  `find`, `readlink`, `mktemp`, `sha256sum`, `stat`, `cmp` e `rmdir`.
- Não é necessário Node.js, OpenCode em execução, rede, Obsidian, root ou um
  gerenciador de dotfiles.
- A origem canônica deve permanecer no caminho físico deste repositório; o
  estado instalado usa destinos absolutos.
- `.env`, credenciais, dependências, caches e conteúdo gerado não fazem parte
  da configuração canônica e nunca são lidos, copiados ou versionados pela
  instalação.

## Uso seguro

As operações de instalação e substituição podem alterar o ambiente. Antes de
usar o destino padrão, faça uma verificação explícita e prefira validar primeiro
em um diretório temporário:

```bash
bin/opencode-config verify --target /tmp/opencode-config-check
bin/opencode-config install --target /tmp/opencode-config-check
bin/opencode-config verify --target /tmp/opencode-config-check
```

Não use `--replace` sem também fornecer `--backup-dir`. Não aponte testes para
`$HOME`, `$XDG_CONFIG_HOME` ou para uma instalação que contenha dados humanos
sem revisar antes o relatório de conflitos. Um `target` existente deve ser um
diretório real, não um link simbólico.

## Destino

Sem `--target`, a CLI usa:

1. `$XDG_CONFIG_HOME/opencode`, quando `XDG_CONFIG_HOME` está definido;
2. `$HOME/.config/opencode`, como fallback.

Para evitar ambiguidade e proteger a instalação real, use um destino explícito:

```bash
bin/opencode-config install --target "/caminho/para/opencode"
```

Paths com espaços são suportados. O destino ausente é criado. A CLI não segue
um link simbólico usado como raiz do destino nem transforma contêineres
preexistentes em links.

## Comandos

### `install`

Executa um preflight completo antes da primeira mutação. Destinos ausentes são
criados e os 75 paths do manifesto gerenciado são publicados como links
granulares. Uma instalação já correta termina em no-op, sem alterar metadata,
links ou estado.

Por padrão, arquivos reais, diretórios, links estrangeiros, links quebrados e
arquivos desconhecidos bloqueiam a instalação e permanecem intactos. A política
estrita continua bloqueando conteúdo desconhecido mesmo quando a substituição
é autorizada.

Para substituir conflitos pertencentes a paths gerenciados, é obrigatório usar
as duas opções abaixo:

```bash
bin/opencode-config install \
  --target "/caminho/para/opencode" \
  --replace \
  --backup-dir "/caminho/para/backups"
```

O backup é criado antes da remoção, em um subdiretório exclusivo de execução,
com permissões restritivas. Arquivos reais preservam o conteúdo; links
estrangeiros e quebrados preservam o alvo literal do link. Falha ao preparar o
backup aborta sem alterar o destino. O arquivo de estado
`.opencode-config-state` é escrito atomicamente e, quando válido, tem modo
`600`.

### `verify`

É uma operação estritamente somente leitura. Ela exige que cada path gerenciado
esteja correto e informa todas as divergências encontradas, incluindo:

- `missing`: link ausente;
- `conflict`: arquivo, diretório ou outro objeto real no lugar do link;
- `conflict_foreign_link`: link existente para outra origem;
- `broken`: link para uma origem ausente ou inválida;
- `unknown`: conteúdo que não está no manifesto nem na lista local permitida.

`.env`, `.gitignore`, lockfiles, `node_modules`, `package.json` e o estado local
permitido são preservados e não são classificados como `unknown`. Uma
verificação com divergências falha sem reparar ou remover nada.

```bash
bin/opencode-config verify --target "/caminho/para/opencode"
```

### `uninstall`

Remove somente links cuja propriedade pode ser provada pelo estado local, pelo
manifesto, pela raiz canônica atual, pelo path relativo e pelo destino literal
atual do link. O conjunto é validado antes da primeira remoção. Estado ausente,
corrompido ou divergente faz a operação falhar sem mutação.

Conteúdo local, arquivos desconhecidos e alterações que não possam ser provadas
como pertencentes à instalação são preservados. Depois da remoção, apenas
diretórios contêineres que estejam vazios são removidos com `rmdir`. Um destino
ausente é um no-op bem-sucedido.

```bash
bin/opencode-config uninstall --target "/caminho/para/opencode"
```

`-h`, `--help` e `help` exibem a interface sem passar pelo gate de plataforma.

## Códigos de saída

- `0`: ajuda exibida, operação concluída, no-op, instalação/verificação bem
  sucedida ou destino ausente no `uninstall`.
- `1`: argumento inválido, plataforma não suportada, manifesto ou destino
  inválido, preflight bloqueado, divergência no `verify`, falta de prova no
  `uninstall`, falha de backup, falha de aplicação ou rollback incompleto.

Não há subcódigos estáveis: qualquer valor diferente de zero deve ser tratado
como falha e o diagnóstico emitido pela CLI deve ser preservado.

## Rollback e recuperação

Durante `install`, cada mutação é registrada. Se a aplicação ou a escrita do
estado falhar, a CLI tenta remover somente links criados na execução atual,
restaurar os conteúdos substituídos e remover apenas contêineres criados que
continuem vazios. Conteúdo anterior não relacionado à execução não é apagado.

Uma falha de restauração permanece audível e retorna erro; o backup não deve ser
apagado automaticamente quando contém material útil para forense. Nesse caso:

1. preserve o destino e o diretório de backup;
2. leia o diagnóstico completo da CLI;
3. execute `verify` no mesmo `--target` para enumerar o estado atual;
4. confira manualmente os backups antes de qualquer nova substituição;
5. só repita `install --replace` depois de resolver itens `unknown` e confirmar
   um diretório de backup gravável e exclusivo.

Não remova manualmente o estado local para contornar uma falha de propriedade.
O `uninstall` exige essa prova justamente para evitar a remoção de conteúdo
humano. Quando não houver backup verificável, a recuperação deve preservar o
original no destino e ser tratada como falha, nunca como sucesso silencioso.

## Preservação de conteúdo local

O instalador gerencia apenas os paths listados em `manifest/managed-files.txt`.
As exceções explícitas em `manifest/local-only.txt` permanecem no destino e não
são copiadas para `config/`. Isso inclui segredos, dependências, lockfiles,
`.gitignore` e o estado local. Arquivos humanos desconhecidos não são apagados:
eles bloqueiam a política estrita até que sejam resolvidos conscientemente.

## Regressão Linux e isolamento dos testes

A suíte usa somente fixtures em diretórios temporários criados com `mktemp`.
Quando testa o destino padrão, ela substitui `HOME` e `XDG_CONFIG_HOME` por
paths temporários e rejeita qualquer fixture que possa alcançar o HOME real.
Nenhum cenário instala, verifica ou desinstala na configuração ativa do
usuário; o repositório canônico é somente lido.

Execute a regressão consolidada e a verificação de sintaxe com:

```bash
bash tests/opencode-config_test.sh all
bash -n bin/opencode-config lib/opencode-config.sh tests/opencode-config_test.sh
```

O cenário `all` executa inventário, manifestos, CLI, preflight, instalação,
rollback e desinstalação em sequência, incluindo as regressões de links,
estado, origem, backup, concorrência simulada e preservação local. O comando
`all` deve ser executado em Linux e não recebe um destino real.
