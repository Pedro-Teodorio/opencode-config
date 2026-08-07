#!/usr/bin/env bash
set -euo pipefail

readonly REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
readonly CONFIG_ROOT="$REPO_ROOT/config"
readonly MANIFEST_ROOT="$REPO_ROOT/manifest"
readonly MANAGED_MANIFEST="$MANIFEST_ROOT/managed-files.txt"
readonly LOCAL_ONLY_MANIFEST="$MANIFEST_ROOT/local-only.txt"
# HOME real do ambiente de teste (antes de qualquer override de fixture).
readonly TEST_REAL_HOME=$(CDPATH= cd -- "${HOME:-/}" && pwd -P)

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

validate_pinned_configuration() {
  local agents_dir="$CONFIG_ROOT/agents"

  grep -Fq '"model": "openai/gpt-5.6-luna"' "$CONFIG_ROOT/opencode.jsonc" \
    || fail 'agent.build deve manter o model pinado openai/gpt-5.6-luna'
  grep -Fq '"reasoningEffort": "high"' "$CONFIG_ROOT/opencode.jsonc" \
    || fail 'agent.build deve manter reasoningEffort high'
  grep -Fq '"@modelcontextprotocol/server-filesystem",' "$CONFIG_ROOT/opencode.jsonc" \
    || fail 'MCP filesystem ausente da configuração canônica'
  grep -Fq '"{env:HOME}",' "$CONFIG_ROOT/opencode.jsonc" \
    || fail 'MCP filesystem deve usar {env:HOME}'

  grep -Fq 'model: openai/gpt-5.6-sol' "$agents_dir/architect.md" \
    || fail 'architect deve manter o model pinado'
  grep -Fq 'model: openai/gpt-5.6-sol' "$agents_dir/planner.md" \
    || fail 'planner deve manter o model pinado'
  grep -Fq 'model: openai/gpt-5.6-luna' "$agents_dir/tdd-guide.md" \
    || fail 'tdd-guide deve manter o model pinado'
  grep -Fq 'model: xai/grok-4.5' "$agents_dir/discussion.md" \
    || fail 'discussion deve manter o model pinado'
  grep -Fq 'model: xai/grok-4.5' "$agents_dir/code-reviewer.md" \
    || fail 'code-reviewer deve manter o model pinado'

  while IFS= read -r agent; do
    grep -Fq 'reasoningEffort: high' "$agents_dir/$agent.md" \
      || fail "$agent deve manter reasoningEffort high"
  done <<'EOF'
architect
planner
tdd-guide
discussion
code-reviewer
EOF
}

inventory() {
  local expected actual path scan_result

  expected=$(cat <<'EOF'
AGENTS.md
agents/architect.md
agents/code-reviewer.md
agents/discussion.md
agents/planner.md
agents/tdd-guide.md
command/approve.md
command/build.md
command/close.md
command/discuss.md
command/init-harness.md
command/spec.md
opencode.jsonc
plugins/rtk.ts
rules/README.md
rules/common/agents.md
rules/common/coding-style.md
rules/common/development-workflow.md
rules/common/git-workflow.md
rules/common/harness.md
rules/common/patterns.md
rules/common/performance.md
rules/common/security.md
rules/common/testing.md
rules/java/coding-style.md
rules/java/patterns.md
rules/java/security.md
rules/java/testing.md
rules/php/coding-style.md
rules/php/patterns.md
rules/php/security.md
rules/php/testing.md
rules/react-native/accessibility.md
rules/react-native/coding-style.md
rules/react-native/hooks.md
rules/react-native/patterns.md
rules/react-native/performance.md
rules/react-native/production-readiness.md
rules/react-native/security.md
rules/react-native/testing.md
rules/react/coding-style.md
rules/react/hooks.md
rules/react/patterns.md
rules/react/security.md
rules/react/testing.md
rules/typescript/coding-style.md
rules/typescript/patterns.md
rules/typescript/security.md
rules/typescript/testing.md
skills/api-design/SKILL.md
skills/backend-patterns/SKILL.md
skills/coding-standards/SKILL.md
skills/frontend-design-direction/SKILL.md
skills/frontend-design/LICENSE.txt
skills/frontend-design/SKILL.md
skills/frontend-patterns/SKILL.md
skills/harness-memory/SKILL.md
skills/harness-memory/references/active-context-template.md
skills/harness-memory/references/bootstrap-vault-skeleton.md
skills/harness-memory/references/harness-schema.md
skills/harness-memory/references/mistake-ledger-template.md
skills/harness-memory/references/session-log-template.md
skills/harness-sdd/SKILL.md
skills/harness-sdd/references/plan-template.md
skills/harness-sdd/references/spec-template.md
skills/harness-sdd/references/tasks-template.md
skills/obsidian-bases/SKILL.md
skills/obsidian-bases/references/FUNCTIONS_REFERENCE.md
skills/obsidian-cli/SKILL.md
skills/obsidian-markdown/SKILL.md
skills/obsidian-markdown/references/CALLOUTS.md
skills/obsidian-markdown/references/EMBEDS.md
skills/obsidian-markdown/references/PROPERTIES.md
skills/tdd/SKILL.md
skills/tdd/agents/openai.yaml
skills/tdd/mocking.md
skills/tdd/tests.md
themes/min-dark.json
EOF
)

  [ -d "$CONFIG_ROOT" ] || fail 'árvore canônica config/ ausente'

  if ! actual=$(CDPATH= cd -- "$CONFIG_ROOT" && find . -type f -print | LC_ALL=C sort | cut -c 3-); then
    fail 'não foi possível varrer os arquivos da árvore canônica'
  fi
  [ "$actual" = "$expected" ] || {
    printf '%s\n' 'Inventário esperado:' "$expected" 'Inventário encontrado:' "$actual" >&2
    fail 'a árvore canônica difere do inventário humano esperado'
  }

  while IFS= read -r path; do
    [ -f "$CONFIG_ROOT/$path" ] || fail "item canônico não é arquivo regular: $path"
    [ ! -L "$CONFIG_ROOT/$path" ] || fail "item canônico não pode ser link simbólico: $path"
  done <<EOF
$expected
EOF

  if ! (CDPATH= cd -- "$CONFIG_ROOT" && sha256sum --check --strict --status <<'EOF'
27f781ba1c68120abb23303696d59603dd9d1a82957ba238485a302d5c59996d  AGENTS.md
23afd3d9dfa8d98455047be254082ba0e0c0780c3ea8a466e958421eb783012d  agents/architect.md
f5c9ed4e20a848dc345da01785720ec86363464fb728b9432db558e6a2546069  agents/code-reviewer.md
9768d0ab86f42188666a68e5009f721514fe72da1ccff917a5260d1dbf6b4b87  agents/discussion.md
15cb348e3c66c3433fa7357c9ccd2ff413488ae9b8c5ad7c886a7efdc9fdabe4  agents/planner.md
60bf63ec75a8128d5ec1ac5db42c18be14610c7d81d9dd62b103ceffec896c0b  agents/tdd-guide.md
c160c18c739fdd661feba5d83305e02820e5d7e799597ea8058a208a1b6ec189  command/approve.md
70d75fc218d4e28245c57b1f9e96a79603c3d6309412ed09f4a16843d29c9668  command/build.md
c140c75172ac73289eae3ed0e736af2f3601ab1fc15f2d8b91e09ccd77589c90  command/close.md
248a3226b36aaf4b87da1c923134e0fb1bc25a41c94dd3d1bbfe31fcbc3c0d96  command/discuss.md
95f86979520ba6fb51488615ef8a231a421ef9475523f28f8edb2d9f188fb489  command/init-harness.md
70a3fa906f24d1339202488d1fb9814da77203ebc99522712a45d1617186a854  command/spec.md
1dcfb0611238bfc78a0f8ba6657aabc24fbc1b99d6435fe24d584d29d1f5a6b2  opencode.jsonc
6530c131946c84892f9522abd68d4e513e1e658d8ddbad1f59388c86ebbcb6bb  plugins/rtk.ts
c023eb141a1d594adb19d2500378b5fabc13613c96d9c995a80a2bdae947e703  rules/README.md
5c98f01ec3c0ab8bba04a82c67a2584e7f9265e5ddc2b0e5781bbe50b1497c65  rules/common/agents.md
52d1da9e124bfbef9f65f0401ec76b48f8e6293c8971969303efd4d7292a6a90  rules/common/coding-style.md
717c24653ae22f55b3e1e17304bdd650672a033c524ac4741871338d23d6e213  rules/common/development-workflow.md
3c9e1ef09c9259b5c714f2f3cf8a50ca9b0c118d789cf8322d1f1cd3b6dd7ff7  rules/common/git-workflow.md
9a9988fce6c70b7bdd7a5f4ba9e6fe205bd37f326ba7ad0e304f6b81d37d2a4b  rules/common/harness.md
8a32c0552c8b309e961ef3f68a56ae84b0b1d411c17f23675ec26b685dea5e9a  rules/common/patterns.md
f631e4abc940e8f2aa7dba779c97f46a4cf58598f6a3bc4e3fdcc418bc4acf3e  rules/common/performance.md
58f0acc56331b8d554dd036b8a1d5b2305a908e3960ff1e2d7e55223d5918bc3  rules/common/security.md
1fe96e1188217bcf35acca3459d9afe00dcfb84bc938bba5abf2c4d8e0d9b4a9  rules/common/testing.md
4ce94d84b6d23615ae5843892bb434dcccd3173938cfffb2701a61c17d1e9a67  rules/java/coding-style.md
4ff895cdd9c4d05f0d1f9651174e6050e819f1633a80bce33662a28db7532abc  rules/java/patterns.md
d3ca12313109954498fa2a33fd03cd9c3d3308d00d4dc4d346829f7cdd91edda  rules/java/security.md
7723d18a6f797a83bba9b492dac55f7e3956a40e4a527c6533aa284d54f14ee0  rules/java/testing.md
e6492b2e6f90a957a2f4664f2e01640fcc5ff77a81ab44c9cee42f3590be8b59  rules/php/coding-style.md
f370b0af1e12d067fb4263ad829f62fedbc37e6e9aedf698d3939b6ee69cd1ea  rules/php/patterns.md
c3ab3949fab80c9bde6d0f6925984dbd094e66b6a790c4cba29f6d74dd07d2b2  rules/php/security.md
027a2fb6619fd671060a6d8283ee6cae2898eee20f26557f75626fc2d18ffdf9  rules/php/testing.md
7cd8adb29406c0f07e6628334bf417e8df3d71a2781c2f830b5b74177b2b8222  rules/react-native/accessibility.md
121c3c1d837828d2a648bcab8f0134fcc711f2fabdfffbdf5a095d60fdeb650f  rules/react-native/coding-style.md
b9b2d1a70bb621b4e6899f76c23b7573ce89d27cc16773b2e5ca03edc8fdc00a  rules/react-native/hooks.md
61ecf0979f22ba323cf03ad29fd98e67671a848127add4b12e3727f3ef76ae9f  rules/react-native/patterns.md
66b87fce7da71f511b1382e52fd5becf3b4edaf6b4dd7a26a68de20b9e451f5d  rules/react-native/performance.md
e4afb1ec82bf7fa541c07c40a71602f76f3a0cb76cc47731c98d5570f2019886  rules/react-native/production-readiness.md
92819918373143837edd33da97af6873562d632d3970b66bfa4d3f4f5cbe5dbd  rules/react-native/security.md
989d2103a46e512dc7c20a7452c8c23b0301b55b0998fb92733f21721dba9382  rules/react-native/testing.md
f799684887ae82e5ebd615a59fb9aff6207328513d13052f00e97e11ac8bb008  rules/react/coding-style.md
64154bbbc881d4b6660376581babae009351ef38f7602ca2d26a640ed253d774  rules/react/hooks.md
36071a93eb6f4be12718f912eae4c31eb68006134a53cc1d76101944d582c2ea  rules/react/patterns.md
52bf239b4b12409417e723e32ff7e1172c39c42d13fa9625eda75a45bd446cec  rules/react/security.md
ae5d05b9e4f706f73f741c3591e880b873da49a7efd02253a381960245bf655f  rules/react/testing.md
cb6fbe555d700a65d466fc27377fbb66d6da0e2bcf4411656918f6a45402af1a  rules/typescript/coding-style.md
20870f78aa32429fe13f35b415e9f6f8f7809e39c460cf8146d181b7306159fd  rules/typescript/patterns.md
7a74c95dfebca6923ab602edfe49688c9e4212defed40579de6fc0bb809f909a  rules/typescript/security.md
92e3d02b4fff30899bc1a2af043d74941adbf3b2c0e972d2fcd2c68c9c2ea70b  rules/typescript/testing.md
7a0ca9c3cec89b2e86cca698c9b947fe136345b5117001b85c4a665515381c94  skills/api-design/SKILL.md
681c33b4e125860295ca2639083cba524c77261e81efd67a3ce30b75593e7512  skills/backend-patterns/SKILL.md
f8a05b67c22e611ff9a56aafe297d63b9f4950d43d3f3f921ef846132b6c5eba  skills/coding-standards/SKILL.md
fa254de821f708e5791c4c80d30309ac7da89c2888301e967becb3b21ac73331  skills/frontend-design-direction/SKILL.md
0d542e0c8804e39aa7f37eb00da5a762149dc682d7829451287e11b938e94594  skills/frontend-design/LICENSE.txt
1608ea77fbb6fc30d13a97d12cfa8ebf31358d40f0dd97beed24829d6b3f45dd  skills/frontend-design/SKILL.md
d32a3f430d658a8a8adb3d05da56fa1b49ef39cf2d1a6be8f27e5164f2d510df  skills/frontend-patterns/SKILL.md
2e051b2d7fe11d3d3bbfa22fec1b126c888fe54cce6bd125cafde092a2e8e64d  skills/harness-memory/SKILL.md
8ec184a2fdc413576f464d5ecd4f677de0c6f0625f62db269d1e19988401b8e5  skills/harness-memory/references/active-context-template.md
fea756063e24e0623f6c6e46dbd0d11f93a0810750bf94b0b3c6aa5028a7f4f9  skills/harness-memory/references/bootstrap-vault-skeleton.md
d071d207321018e5fb3e5a1ba922a8ad6719e6f68e278ff788b88da105cca025  skills/harness-memory/references/harness-schema.md
e6cbea1c1d3e0291ed358e11fd5c8d614d3b6aa6bddea8d3f322d90c97091af8  skills/harness-memory/references/mistake-ledger-template.md
f495a6c4f40f32734d83d8f595fc73595a0777bff3a301291635795d4273e6e1  skills/harness-memory/references/session-log-template.md
30059e787adf320f666bf41b9b5de1dfb4f30a679ce0283bb3bc7386f808663b  skills/harness-sdd/SKILL.md
ba05ac3ff2fe0de07c48d6d1756e9dcfd14784d8b8c99a38a0d1b1aa5b08374f  skills/harness-sdd/references/plan-template.md
2606469f839b743ea161ea6102a55937eb3677a3cc151f59c4bc7b25e9bec18b  skills/harness-sdd/references/spec-template.md
0873c1435e9a3aea00471c17dc367f81f75543c597ab9f542b00c3813329657b  skills/harness-sdd/references/tasks-template.md
c0037f20926c7d8591cdd040365e4c0e4c0c4146386a506f28f241faee9a27d9  skills/obsidian-bases/SKILL.md
208fd63aead9bca1975626fea52605e6ab9434dc0529d923feb36b18b8877d3b  skills/obsidian-bases/references/FUNCTIONS_REFERENCE.md
b54257cdc0e5d04488b35b0c797bfe427b24359f0848d3c73924dcacf8da6358  skills/obsidian-cli/SKILL.md
7ad72e1f0a9081ed325e76b6402ad5de50a00e63e2341fd403a92f147234a007  skills/obsidian-markdown/SKILL.md
9912ec2e3f8711f65b8ceb82cc19cbffc5e6f8ccf2ab627e18926c522c383d8b  skills/obsidian-markdown/references/CALLOUTS.md
63b6205507e28fb58cf200bc348a2b139e50ae739743e2e6316732148973cb7a  skills/obsidian-markdown/references/EMBEDS.md
392953b5838c3ab3df135b5a914f100ae7b95e4501b6a2e5c8dc63da3ac7558b  skills/obsidian-markdown/references/PROPERTIES.md
5363bb2775679fe9311fbb67947f95359169c6e7f1fac77c0f25e190bca6cf2f  skills/tdd/SKILL.md
ea6f01cf1b8c06a4b0f5b649d74b1b8ce8685e72af1b38d70d877693e092af0b  skills/tdd/agents/openai.yaml
3ceb807fdf4a47d6a93d4d9a891e5ba6d362a6247bd08adc451feebfc17361ef  skills/tdd/mocking.md
859f9e592c188fda4fc7277dd180e4ce9c7a2e13f6efe1f6f29eccc9d28c106a  skills/tdd/tests.md
83914bbe49aa84ce9c0b8e02f1e8c256421fcadb1f94dbd39352135b6cf78b70  themes/min-dark.json
EOF
  ); then
    fail 'conteúdo canônico difere dos checksums SHA-256 revisados ou não pôde ser lido'
  fi

  if ! scan_result=$(find "$CONFIG_ROOT" -type l -print -quit); then
    fail 'não foi possível varrer links simbólicos na árvore canônica'
  fi
  if [ -n "$scan_result" ]; then
    fail 'a árvore canônica contém link simbólico inesperado'
  fi

  if ! scan_result=$(find "$CONFIG_ROOT" -mindepth 1 -type d -empty -print -quit); then
    fail 'não foi possível varrer diretórios vazios na árvore canônica'
  fi
  if [ -n "$scan_result" ]; then
    fail 'a árvore canônica contém diretório vazio inesperado'
  fi

  if ! scan_result=$(find "$CONFIG_ROOT" \( \
      -name '.env' -o -name '.env.*' -o -name '.gitignore' -o \
      -name 'package.json' -o -name 'package-lock.json' -o \
      -name 'npm-shrinkwrap.json' -o -name 'yarn.lock' -o \
      -name 'pnpm-lock.yaml' -o -name 'bun.lock' -o -name 'bun.lockb' -o \
      -name 'node_modules' \
    \) -print -quit); then
    fail 'não foi possível varrer conteúdo excluído na árvore canônica'
  fi
  if [ -n "$scan_result" ]; then
    fail 'a árvore canônica contém conteúdo sensível ou gerado excluído'
  fi

  validate_pinned_configuration

  printf 'PASS: inventory\n'
}

validate_manifest_paths() {
  local manifest_name=$1 manifest_path=$2 path grep_status

  [ -f "$manifest_path" ] || fail "manifesto ausente: $manifest_name"
  [ ! -L "$manifest_path" ] || fail "manifesto não pode ser link simbólico: $manifest_name"
  [ -s "$manifest_path" ] || fail "manifesto vazio: $manifest_name"

  if grep -n '^$' "$manifest_path" >/dev/null; then
    fail "manifesto contém linha vazia: $manifest_name"
  else
    grep_status=$?
    [ "$grep_status" -eq 1 ] || fail "não foi possível verificar linhas vazias no manifesto: $manifest_name"
  fi
  if LC_ALL=C grep -n '[[:cntrl:]]' "$manifest_path" >/dev/null; then
    fail "manifesto contém caractere de controle: $manifest_name"
  else
    grep_status=$?
    [ "$grep_status" -eq 1 ] || fail "não foi possível verificar caracteres de controle no manifesto: $manifest_name"
  fi

  while IFS= read -r path || [ -n "$path" ]; do
    [ -n "$path" ] || fail "manifesto contém linha vazia: $manifest_name"
    case "$path" in
      /*) fail "manifesto contém path absoluto: $manifest_name: $path" ;;
      */) fail "manifesto contém barra final: $manifest_name: $path" ;;
      *\\*) fail "manifesto contém backslash: $manifest_name: $path" ;;
    esac
    case "/$path/" in
      */./*|*/../*) fail "manifesto contém componente inseguro: $manifest_name: $path" ;;
    esac
  done < "$manifest_path"
}

create_manifest_fixture() {
  local fixture_root=$1

  mkdir -p "$fixture_root/tests"
  cp "$0" "$fixture_root/tests/opencode-config_test.sh"
  cp -R "$CONFIG_ROOT" "$fixture_root/config"
  cp -R "$MANIFEST_ROOT" "$fixture_root/manifest"
}

manifest_rejects_extra_symlink() {
  local fixture_root

  fixture_root=$(mktemp -d)
  create_manifest_fixture "$fixture_root"
  ln -s AGENTS.md "$fixture_root/config/unexpected-link"

  if OPENCODE_CONFIG_SKIP_MANIFEST_REGRESSIONS=1 \
      bash "$fixture_root/tests/opencode-config_test.sh" manifest >/dev/null 2>&1; then
    rm -rf "$fixture_root"
    return 1
  fi
  rm -rf "$fixture_root"
}

manifest_rejects_symlink_config_root() {
  local fixture_root physical_config

  fixture_root=$(mktemp -d)
  create_manifest_fixture "$fixture_root"
  physical_config="$fixture_root/config-physical"
  mv "$fixture_root/config" "$physical_config"
  ln -s "$physical_config" "$fixture_root/config"

  if OPENCODE_CONFIG_SKIP_MANIFEST_REGRESSIONS=1 \
      bash "$fixture_root/tests/opencode-config_test.sh" manifest >/dev/null 2>&1; then
    rm -rf "$fixture_root"
    return 1
  fi
  rm -rf "$fixture_root"
}

manifest_rejects_grep_operational_error() {
  local fixture_root

  fixture_root=$(mktemp -d)
  create_manifest_fixture "$fixture_root"
  mkdir "$fixture_root/bin"
  cat > "$fixture_root/bin/grep" <<'EOF'
#!/usr/bin/env bash
case "${FAKE_GREP_ERROR_CHECK:-}:$2" in
  empty:'^$'|control:'[[:cntrl:]]') exit 2 ;;
  *) exit 1 ;;
esac
EOF
  chmod +x "$fixture_root/bin/grep"

  if PATH="$fixture_root/bin:$PATH" FAKE_GREP_ERROR_CHECK=empty \
      OPENCODE_CONFIG_SKIP_MANIFEST_REGRESSIONS=1 \
      bash "$fixture_root/tests/opencode-config_test.sh" manifest >/dev/null 2>&1; then
    rm -rf "$fixture_root"
    return 1
  fi
  if PATH="$fixture_root/bin:$PATH" FAKE_GREP_ERROR_CHECK=control \
      OPENCODE_CONFIG_SKIP_MANIFEST_REGRESSIONS=1 \
      bash "$fixture_root/tests/opencode-config_test.sh" manifest >/dev/null 2>&1; then
    rm -rf "$fixture_root"
    return 1
  fi
  rm -rf "$fixture_root"
}

run_manifest_regressions() {
  local failures=0

  manifest_rejects_extra_symlink || {
    printf '%s\n' 'RED: symlink extra dentro de config/ resultou em PASS' >&2
    failures=$((failures + 1))
  }
  manifest_rejects_symlink_config_root || {
    printf '%s\n' 'RED: config/ raiz como symlink resultou em PASS' >&2
    failures=$((failures + 1))
  }
  manifest_rejects_grep_operational_error || {
    printf '%s\n' 'RED: erro operacional de grep foi interpretado como ausência de linhas inválidas' >&2
    failures=$((failures + 1))
  }

  [ "$failures" -eq 0 ] || fail "$failures regressão(ões) bloqueante(s) do cenário manifest"
}

manifest() {
  local actual config_physical managed expected_local local_only overlap scan_result sorted unique count

  [ -d "$CONFIG_ROOT" ] || fail 'árvore canônica config/ ausente'
  [ ! -L "$CONFIG_ROOT" ] || fail 'a raiz canônica config/ não pode ser link simbólico'
  if ! config_physical=$(CDPATH= cd -- "$CONFIG_ROOT" && pwd -P); then
    fail 'não foi possível resolver a raiz física da árvore canônica'
  fi
  [ "$config_physical" = "$CONFIG_ROOT" ] || fail 'a raiz física config/ não corresponde à árvore esperada dentro da raiz física do repositório'

  if ! scan_result=$(find "$CONFIG_ROOT" -type l -print -quit); then
    fail 'não foi possível varrer links simbólicos na árvore canônica'
  fi
  [ -z "$scan_result" ] || fail 'a árvore canônica contém link simbólico inesperado'

  validate_manifest_paths 'managed-files.txt' "$MANAGED_MANIFEST"
  validate_manifest_paths 'local-only.txt' "$LOCAL_ONLY_MANIFEST"

  if ! actual=$(CDPATH= cd -- "$CONFIG_ROOT" && find . -type f -print | LC_ALL=C sort | cut -c 3-); then
    fail 'não foi possível varrer a árvore canônica para validar o manifesto'
  fi
  managed=$(<"$MANAGED_MANIFEST")
  [ "$managed" = "$actual" ] || fail 'managed-files.txt não corresponde exatamente à árvore config/'

  count=$(wc -l < "$MANAGED_MANIFEST")
  [ "$count" -eq 78 ] || fail "managed-files.txt deve declarar exatamente 78 arquivos; encontrados: $count"

  sorted=$(LC_ALL=C sort "$MANAGED_MANIFEST")
  [ "$managed" = "$sorted" ] || fail 'managed-files.txt não está deterministicamente ordenado'
  unique=$(LC_ALL=C sort -u "$MANAGED_MANIFEST")
  [ "$managed" = "$unique" ] || fail 'managed-files.txt contém entradas duplicadas'

  expected_local=$(cat <<'EOF'
.env
.gitignore
.opencode-config-state
bun.lock
bun.lockb
node_modules
npm-shrinkwrap.json
package-lock.json
package.json
pnpm-lock.yaml
yarn.lock
EOF
)
  local_only=$(<"$LOCAL_ONLY_MANIFEST")
  [ "$local_only" = "$expected_local" ] || fail 'local-only.txt difere do conjunto explícito de exceções locais'

  sorted=$(LC_ALL=C sort "$LOCAL_ONLY_MANIFEST")
  [ "$local_only" = "$sorted" ] || fail 'local-only.txt não está deterministicamente ordenado'
  unique=$(LC_ALL=C sort -u "$LOCAL_ONLY_MANIFEST")
  [ "$local_only" = "$unique" ] || fail 'local-only.txt contém entradas duplicadas'

  overlap=$(LC_ALL=C comm -12 "$MANAGED_MANIFEST" "$LOCAL_ONLY_MANIFEST")
  [ -z "$overlap" ] || fail "manifestos possuem entradas sobrepostas: $overlap"

  if [ "${OPENCODE_CONFIG_SKIP_MANIFEST_REGRESSIONS:-0}" != 1 ]; then
    run_manifest_regressions
  fi

  printf 'PASS: manifest\n'
}

cli_bin() {
  printf '%s\n' "$REPO_ROOT/bin/opencode-config"
}

# Executa a CLI capturando stdout+stderr e código de saída sem abortar o teste.
# Usa nameref para gravar nos locals do caller (bash ≥ 4.3).
run_cli() {
  local -n _run_cli_output=$1
  local -n _run_cli_status=$2
  shift 2
  set +e
  _run_cli_output=$("$(cli_bin)" "$@" 2>&1)
  _run_cli_status=$?
  set -e
}

assert_contains() {
  local haystack=$1 needle=$2 message=$3
  case "$haystack" in
    *"$needle"*) ;;
    *) fail "$message (esperado conter: $needle)" ;;
  esac
}

assert_exit_zero() {
  local status=$1 message=$2
  [ "$status" -eq 0 ] || fail "$message (exit=$status)"
}

assert_exit_nonzero() {
  local status=$1 message=$2
  [ "$status" -ne 0 ] || fail "$message (exit=0 inesperado)"
}

# Garante que fixtures nunca apontem para o HOME real do ambiente de teste.
assert_safe_target_context() {
  local target_home
  target_home=$(CDPATH= cd -- "$1" && pwd -P 2>/dev/null || printf '%s\n' "$1")
  [ -n "$TEST_REAL_HOME" ] || fail 'HOME real indisponível para checagem de isolamento'
  case "$target_home" in
    "$TEST_REAL_HOME"|"$TEST_REAL_HOME"/*)
      fail "teste recusou destino que tocaria o HOME real: $target_home"
      ;;
  esac
}

cli_help_surface() {
  local out status

  run_cli out status
  assert_exit_zero "$status" 'sem argumentos deve exibir ajuda com sucesso'
  assert_contains "$out" 'Usage:' 'ajuda sem argumentos'
  assert_contains "$out" 'install' 'ajuda lista install'
  assert_contains "$out" 'verify' 'ajuda lista verify'
  assert_contains "$out" 'uninstall' 'ajuda lista uninstall'

  run_cli out status -h
  assert_exit_zero "$status" '-h deve exibir ajuda'
  assert_contains "$out" 'Usage:' 'ajuda via -h'

  run_cli out status --help
  assert_exit_zero "$status" '--help deve exibir ajuda'
  assert_contains "$out" 'Usage:' 'ajuda via --help'

  run_cli out status help
  assert_exit_zero "$status" 'comando help deve exibir ajuda'
  assert_contains "$out" 'Usage:' 'ajuda via help'
}

cli_valid_commands() {
  local out status tmp target link_count

  tmp=$(mktemp -d)
  target="$tmp/opencode-target"
  mkdir -p "$target"
  assert_safe_target_context "$tmp"

  # T5: install aplica a projeção gerenciada.
  run_cli out status install --target "$target"
  assert_exit_zero "$status" 'install com --target vazio deve concluir'
  assert_contains "$out" 'installed' 'install deve reportar aplicação'
  assert_contains "$out" "$target" 'install deve ecoar o --target'

  # Verify estrito passa após instalação.
  run_cli out status verify --target "$target"
  assert_exit_zero "$status" 'verify após install deve passar'
  assert_contains "$out" 'OK' 'verify deve reportar OK'

  # uninstall remove somente os links cuja propriedade foi comprovada pelo state.
  run_cli out status uninstall --target "$target"
  assert_exit_zero "$status" 'uninstall com --target deve remover instalação válida'
  assert_contains "$out" 'uninstalled' 'uninstall deve reportar remoção'

  link_count=$(find "$target" -type l | wc -l)
  [ "$link_count" -eq 0 ] || fail "uninstall deve remover 78 links; restantes: $link_count"
  [ ! -e "$target/.opencode-config-state" ] || fail 'uninstall deve remover state válido'

  rm -rf "$tmp"
}

cli_invalid_arguments() {
  local out status tmp

  tmp=$(mktemp -d)
  assert_safe_target_context "$tmp"

  run_cli out status frobozz
  assert_exit_nonzero "$status" 'comando desconhecido deve falhar'
  assert_contains "$out" 'unknown' 'mensagem de comando desconhecido'

  run_cli out status install --nope
  assert_exit_nonzero "$status" 'flag desconhecida deve falhar'
  assert_contains "$out" 'unknown' 'mensagem de flag desconhecida'

  run_cli out status install --target
  assert_exit_nonzero "$status" '--target sem valor deve falhar'

  run_cli out status verify --replace
  assert_exit_nonzero "$status" 'verify não aceita --replace'

  run_cli out status uninstall --backup-dir "$tmp/bak"
  assert_exit_nonzero "$status" 'uninstall não aceita --backup-dir'

  rm -rf "$tmp"
}

cli_replace_backup_combination() {
  local out status tmp target backup

  tmp=$(mktemp -d)
  target="$tmp/target"
  backup="$tmp/backup"
  mkdir -p "$target" "$backup"
  assert_safe_target_context "$tmp"

  run_cli out status install --target "$target" --replace
  assert_exit_nonzero "$status" 'replace sozinho deve falhar'
  assert_contains "$out" 'backup' 'replace sozinho menciona backup'

  run_cli out status install --target "$target" --backup-dir "$backup"
  assert_exit_nonzero "$status" 'backup-dir sozinho deve falhar'
  assert_contains "$out" 'replace' 'backup-dir sozinho menciona replace'

  run_cli out status install --target "$target" --replace --backup-dir "$backup"
  assert_exit_zero "$status" 'replace + backup-dir juntos devem instalar quando não há conflito'
  assert_contains "$out" 'installed' 'install com replace+backup sem conflito deve aplicar T5'

  # install sem replace/backup (não destrutivo) é válido no parse
  run_cli out status install --target "$target"
  assert_exit_zero "$status" 'install sem replace/backup deve ser aceito'

  rm -rf "$tmp"
}

cli_xdg_home_resolution() {
  local tmp

  # Com XDG_CONFIG_HOME (inclui espaço no path)
  tmp=$(mktemp -d)
  (
    local out status expected
    export HOME="$tmp/home-real"
    export XDG_CONFIG_HOME="$tmp/xdg config"
    mkdir -p "$HOME" "$XDG_CONFIG_HOME"
    assert_safe_target_context "$HOME"
    expected="$XDG_CONFIG_HOME/opencode"

    run_cli out status install
    assert_exit_zero "$status" 'install com XDG deve resolver e criar destino padrão'
    assert_contains "$out" "$expected" 'destino padrão deve usar XDG_CONFIG_HOME/opencode'
    [ -L "$expected/AGENTS.md" ] || fail 'install padrão XDG não criou link gerenciado'
  )
  rm -rf "$tmp"

  # Sem XDG_CONFIG_HOME → $HOME/.config/opencode (HOME com espaços)
  tmp=$(mktemp -d)
  (
    local out status expected
    export HOME="$tmp/home with spaces"
    unset XDG_CONFIG_HOME || true
    mkdir -p "$HOME"
    assert_safe_target_context "$HOME"
    expected="$HOME/.config/opencode"

    run_cli out status verify
    # Destino padrão inexistente/vazio: verify estrito falha, mas deve citar o path.
    assert_exit_nonzero "$status" 'verify sem XDG em destino vazio deve falhar'
    assert_contains "$out" "$expected" 'destino padrão deve usar HOME/.config/opencode'
  )
  rm -rf "$tmp"
}

cli_non_linux_refusal() {
  local out status tmp target

  tmp=$(mktemp -d)
  target="$tmp/target"
  mkdir -p "$target"
  assert_safe_target_context "$tmp"

  # OPENCODE_CONFIG_FORCE_OS simula uname para testabilidade (sem fake binário).
  set +e
  out=$(OPENCODE_CONFIG_FORCE_OS=darwin "$(cli_bin)" install --target "$target" 2>&1)
  status=$?
  set -e
  assert_exit_nonzero "$status" 'plataforma não-Linux deve ser recusada'
  assert_contains "$out" 'Linux' 'recusa deve mencionar Linux'

  set +e
  out=$(OPENCODE_CONFIG_FORCE_OS=darwin "$(cli_bin)" verify --target "$target" 2>&1)
  status=$?
  set -e
  assert_exit_nonzero "$status" 'verify em não-Linux deve falhar'

  set +e
  out=$(OPENCODE_CONFIG_FORCE_OS=darwin "$(cli_bin)" uninstall --target "$target" 2>&1)
  status=$?
  set -e
  assert_exit_nonzero "$status" 'uninstall em não-Linux deve falhar'

  rm -rf "$tmp"
}

cli_entrypoint_and_lib() {
  local bin lib out status

  bin=$(cli_bin)
  lib="$REPO_ROOT/lib/opencode-config.sh"

  [ -f "$bin" ] || fail 'bin/opencode-config ausente'
  [ -x "$bin" ] || fail 'bin/opencode-config deve ser executável'
  [ -f "$lib" ] || fail 'lib/opencode-config.sh ausente'

  # Entrypoint deve referenciar a lib relativa ao layout do repo
  grep -q 'opencode-config.sh' "$bin" || fail 'entrypoint deve sourcear lib/opencode-config.sh'

  run_cli out status --help
  assert_exit_zero "$status" 'entrypoint executável deve responder a --help'
}

cli_paths_with_spaces() {
  local out status tmp target backup

  tmp=$(mktemp -d)
  target="$tmp/dest with spaces/opencode"
  backup="$tmp/back up dir"
  mkdir -p "$target" "$backup"
  assert_safe_target_context "$tmp"

  run_cli out status install --target "$target" --replace --backup-dir "$backup"
  assert_exit_zero "$status" 'paths com espaços devem ser aceitos no install'
  assert_contains "$out" 'installed' 'install com paths espaçados deve aplicar'
  assert_contains "$out" "$target" 'install deve ecoar target com espaços'

  run_cli out status verify --target "$target"
  assert_exit_zero "$status" 'verify com path espaçado instalado deve passar'
  assert_contains "$out" "$target" 'verify deve ecoar target com espaços'

  rm -rf "$tmp"
}

cli() {
  local bin

  bin=$(cli_bin)
  [ -e "$bin" ] || fail 'bin/opencode-config ausente (esperado pela T3)'

  cli_entrypoint_and_lib
  cli_help_surface
  cli_valid_commands
  cli_invalid_arguments
  cli_replace_backup_combination
  cli_xdg_home_resolution
  cli_non_linux_refusal
  cli_paths_with_spaces

  printf 'PASS: cli\n'
}

# --- T4: preflight total + verify estrito ------------------------------------

# Snapshot estável do destino para provar ausência de mutação.
preflight_fingerprint() {
  local target=$1
  if [ ! -d "$target" ]; then
    printf 'ABSENT\n'
    return 0
  fi
  # Lista paths + tipo + alvo de symlink (quando houver); independente de mtime.
  (
    CDPATH= cd -- "$target" || exit 1
    find . -print | LC_ALL=C sort | while IFS= read -r p; do
      if [ -L "$p" ]; then
        printf 'L\t%s\t%s\n' "$p" "$(readlink -- "$p")"
      elif [ -d "$p" ]; then
        printf 'D\t%s\n' "$p"
      elif [ -f "$p" ]; then
        printf 'F\t%s\n' "$p"
      else
        printf '?\t%s\n' "$p"
      fi
    done
  ) | sha256sum | awk '{print $1}'
}

# Snapshot forte para idempotência: paths, tipo, modo, inode, timestamps, tamanho,
# alvo literal dos links e checksum do estado local.
install_fingerprint() {
  local target=$1 p metadata state_hash='-'

  [ -d "$target" ] || {
    printf 'ABSENT\n'
    return 0
  }
  if [ -f "$target/.opencode-config-state" ] && [ ! -L "$target/.opencode-config-state" ]; then
    state_hash=$(sha256sum -- "$target/.opencode-config-state" | awk '{print $1}')
  fi
  (
    CDPATH= cd -- "$target" || exit 1
    find . -print | LC_ALL=C sort | while IFS= read -r p; do
      metadata=$(stat -c '%F|%a|%i|%s|%y|%z' -- "$p")
      if [ -L "$p" ]; then
        printf '%s|%s|target=%s\n' "$p" "$metadata" "$(readlink -- "$p")"
      else
        printf '%s|%s\n' "$p" "$metadata"
      fi
    done
    printf 'state-sha256=%s\n' "$state_hash"
  ) | sha256sum | awk '{print $1}'
}

run_cli_with_config_root() {
  local -n _run_fixture_output=$1
  local -n _run_fixture_status=$2
  local config_root=$3
  shift 3
  set +e
  _run_fixture_output=$(OCC_CONFIG_ROOT="$config_root" "$(cli_bin)" "$@" 2>&1)
  _run_fixture_status=$?
  set -e
}

# Sourceia a biblioteca em subprocesso e substitui somente hooks internos de
# teste. Nenhuma variável é avaliada como código pela implementação de produção.
run_cli_with_internal_hook() {
  local -n _run_hook_output=$1
  local -n _run_hook_status=$2
  local hook_kind=$3 target=$4 external=$5
  local hook_config_root=${OCC_HOOK_CONFIG_ROOT:-$CONFIG_ROOT}
  shift 5
  set +e
  _run_hook_output=$(
    OCC_ATTACK_TARGET="$target" OCC_ATTACK_EXTERNAL="$external" \
      OCC_CONFIG_ROOT="$hook_config_root" \
      bash -c '
        set -euo pipefail
        . "$1/lib/opencode-config.sh"
        case "$2" in
          link-final)
            opencode_config_test_hook_before_link_publish() {
              [ "$1" = AGENTS.md ] || return 0
              ln -s -- "$OCC_ATTACK_EXTERNAL" "$OCC_ATTACK_TARGET/AGENTS.md"
            }
            ;;
          link-container)
            opencode_config_test_hook_before_link_publish() {
              [ "$1" = agents/architect.md ] || return 0
              mv -- "$OCC_ATTACK_TARGET/agents" "$OCC_ATTACK_TARGET/agents-original"
              ln -s -- "$OCC_ATTACK_EXTERNAL" "$OCC_ATTACK_TARGET/agents"
            }
            ;;
          link-container-after-check)
            opencode_config_test_hook_after_link_validation_before_publish() {
              [ "$1" = agents/architect.md ] || return 0
              mkdir -p -- "$OCC_ATTACK_EXTERNAL"
              mv -- "$OCC_ATTACK_TARGET/agents" "$OCC_ATTACK_EXTERNAL/moved-agents"
              mkdir -- "$OCC_ATTACK_TARGET/agents"
            }
            ;;
          state-file)
            opencode_config_test_hook_before_state_publish() {
              ln -s -- "$OCC_ATTACK_EXTERNAL" "$OCC_ATTACK_TARGET/.opencode-config-state"
            }
            ;;
          state-dir)
            opencode_config_test_hook_before_state_publish() {
              rm -f -- "$OCC_ATTACK_TARGET/.opencode-config-state"
              ln -s -- "$OCC_ATTACK_EXTERNAL" "$OCC_ATTACK_TARGET/.opencode-config-state"
            }
            ;;
          state-target-after-check)
            opencode_config_test_hook_after_state_validation_before_temp() {
              mkdir -p -- "$OCC_ATTACK_EXTERNAL"
              mv -- "$OCC_ATTACK_TARGET" "$OCC_ATTACK_EXTERNAL/moved-target"
              mkdir -- "$OCC_ATTACK_TARGET"
            }
            ;;
          source-swap)
            opencode_config_test_hook_after_source_validation() {
              [ "$1" = themes/min-dark.json ] || return 0
              mv -- "$OCC_CONFIG_ROOT/themes" "$OCC_CONFIG_ROOT/themes-original"
              ln -s -- "$OCC_ATTACK_EXTERNAL" "$OCC_CONFIG_ROOT/themes"
            }
            ;;
          backup-fail)
            opencode_config_test_hook_before_item_backup() {
              return 1
            }
            ;;
          mid-apply-fail)
            opencode_config_test_hook_after_mutation() {
              # Falha após N mutações bem-sucedidas (N em OCC_ATTACK_EXTERNAL).
              if [ "${1:-0}" -ge "${OCC_ATTACK_EXTERNAL:-1}" ]; then
                opencode_config_die "injected mid-apply failure after $1 mutations"
                return 1
              fi
            }
            ;;
          *) exit 97 ;;
        esac
        shift 2
        opencode_config_main "$@"
      ' _ "$REPO_ROOT" "$hook_kind" "$@" 2>&1
  )
  _run_hook_status=$?
  set -e
}

# Cria symlinks corretos (absolutos) para todos os managed paths.
preflight_seed_correct_links() {
  local target=$1
  local path dest dir

  [ -d "$target" ] || mkdir -p "$target"
  while IFS= read -r path || [ -n "$path" ]; do
    [ -n "$path" ] || continue
    dest="$target/$path"
    dir=$(dirname -- "$dest")
    mkdir -p "$dir"
    ln -sfn -- "$CONFIG_ROOT/$path" "$dest"
  done < "$MANAGED_MANIFEST"
}

preflight_multiple_divergences_reported() {
  local tmp target out status fp_before fp_after

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  mkdir -p "$target/agents" "$target/themes"
  assert_safe_target_context "$tmp"

  # conflict_file
  printf 'human\n' > "$target/AGENTS.md"
  # conflict_foreign_link (alvo estrangeiro existente)
  printf 'foreign\n' > "$tmp/foreign-origin.jsonc"
  ln -s "$tmp/foreign-origin.jsonc" "$target/opencode.jsonc"
  # broken_link (managed path aponta para destino inexistente)
  ln -s "$target/does-not-exist-canonical.md" "$target/themes/min-dark.json"
  # unknown human config
  printf 'extra\n' > "$target/human-extra.conf"
  # agents/architect.md permanece missing (não criado)

  fp_before=$(preflight_fingerprint "$target")

  run_cli out status verify --target "$target"
  assert_exit_nonzero "$status" 'verify com múltiplas divergências deve falhar'
  assert_contains "$out" 'AGENTS.md' 'verify deve citar conflict file AGENTS.md'
  assert_contains "$out" 'conflict' 'verify deve classificar conflito'
  assert_contains "$out" 'opencode.jsonc' 'verify deve citar foreign link'
  assert_contains "$out" 'foreign' 'verify deve reportar origem estrangeira'
  assert_contains "$out" 'themes/min-dark.json' 'verify deve citar broken link'
  assert_contains "$out" 'broken' 'verify deve classificar broken'
  assert_contains "$out" 'human-extra.conf' 'verify deve citar unknown'
  assert_contains "$out" 'unknown' 'verify deve classificar unknown'
  assert_contains "$out" 'agents/architect.md' 'verify deve citar missing'
  assert_contains "$out" 'missing' 'verify deve classificar missing'

  fp_after=$(preflight_fingerprint "$target")
  [ "$fp_before" = "$fp_after" ] || fail 'verify mutou o destino (fingerprint divergiu)'

  rm -rf "$tmp"
}

preflight_install_conflicts_no_mutate() {
  local tmp target out status fp_before fp_after

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  mkdir -p "$target"
  assert_safe_target_context "$tmp"

  printf 'block\n' > "$target/AGENTS.md"
  printf 'stray\n' > "$target/unknown-file.txt"
  printf 'hosts-like\n' > "$tmp/foreign-hosts"
  ln -s "$tmp/foreign-hosts" "$target/opencode.jsonc"

  fp_before=$(preflight_fingerprint "$target")

  run_cli out status install --target "$target"
  assert_exit_nonzero "$status" 'install com conflitos deve abortar no preflight'
  assert_contains "$out" 'conflict' 'install preflight deve reportar conflict'
  assert_contains "$out" 'unknown' 'install preflight deve reportar unknown'
  assert_contains "$out" 'foreign' 'install preflight deve reportar foreign'
  assert_contains "$out" 'AGENTS.md' 'install deve listar AGENTS.md'
  assert_contains "$out" 'unknown-file.txt' 'install deve listar unknown-file.txt'
  assert_contains "$out" 'opencode.jsonc' 'install deve listar foreign link'

  fp_after=$(preflight_fingerprint "$target")
  [ "$fp_before" = "$fp_after" ] || fail 'install com conflitos mutou o destino'

  # Conteúdo original intacto
  [ "$(cat "$target/AGENTS.md")" = 'block' ] || fail 'AGENTS.md foi alterado no preflight'
  [ -f "$target/unknown-file.txt" ] || fail 'unknown foi removido no preflight'

  rm -rf "$tmp"
}

preflight_verify_correct_full_install() {
  local tmp target out status

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  assert_safe_target_context "$tmp"
  preflight_seed_correct_links "$target"

  run_cli out status verify --target "$target"
  assert_exit_zero "$status" 'verify em instalação correta deve passar'
  assert_contains "$out" 'OK' 'verify sucesso deve indicar OK'

  rm -rf "$tmp"
}

preflight_verify_unknown_fails() {
  local tmp target out status fp_before fp_after

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  assert_safe_target_context "$tmp"
  preflight_seed_correct_links "$target"
  printf 'nope\n' > "$target/not-in-manifest.cfg"

  fp_before=$(preflight_fingerprint "$target")
  run_cli out status verify --target "$target"
  assert_exit_nonzero "$status" 'verify deve falhar com unknown'
  assert_contains "$out" 'unknown' 'verify deve marcar unknown'
  assert_contains "$out" 'not-in-manifest.cfg' 'verify deve citar o arquivo unknown'
  fp_after=$(preflight_fingerprint "$target")
  [ "$fp_before" = "$fp_after" ] || fail 'verify removeu/alterou unknown'
  [ -f "$target/not-in-manifest.cfg" ] || fail 'unknown não deve ser removido'

  rm -rf "$tmp"
}

preflight_verify_local_only_allowed() {
  local tmp target out status

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  assert_safe_target_context "$tmp"
  preflight_seed_correct_links "$target"

  printf 'SECRET=1\n' > "$target/.env"
  mkdir -p "$target/node_modules/pkg"
  printf 'mod\n' > "$target/node_modules/pkg/index.js"
  printf 'state\n' > "$target/.opencode-config-state"
  printf 'ign\n' > "$target/.gitignore"

  run_cli out status verify --target "$target"
  assert_exit_zero "$status" 'verify deve aceitar local-only (.env, node_modules, state)'
  case "$out" in
    *unknown*) fail 'local-only não pode ser classificado como unknown' ;;
  esac

  # Preservados
  [ -f "$target/.env" ] || fail '.env foi removido'
  [ -d "$target/node_modules" ] || fail 'node_modules foi removido'
  [ -f "$target/.opencode-config-state" ] || fail 'state foi removido'

  rm -rf "$tmp"
}

preflight_verify_broken_and_wrong_target() {
  local tmp target out status

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  assert_safe_target_context "$tmp"
  preflight_seed_correct_links "$target"

  # Quebra um link (destino canônico inexistente)
  rm -f "$target/AGENTS.md"
  ln -s "$CONFIG_ROOT/AGENTS.md.missing" "$target/AGENTS.md"

  run_cli out status verify --target "$target"
  assert_exit_nonzero "$status" 'verify deve falhar com broken link'
  assert_contains "$out" 'broken' 'verify deve reportar broken'
  assert_contains "$out" 'AGENTS.md' 'verify broken deve citar AGENTS.md'

  # Link para origem errada existente
  rm -f "$target/opencode.jsonc"
  ln -s /etc/hosts "$target/opencode.jsonc"

  run_cli out status verify --target "$target"
  assert_exit_nonzero "$status" 'verify deve falhar com foreign link'
  assert_contains "$out" 'foreign' 'verify deve reportar foreign'
  assert_contains "$out" 'opencode.jsonc' 'verify foreign deve citar opencode.jsonc'

  rm -rf "$tmp"
}

preflight_verify_real_file_conflict() {
  local tmp target out status

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  assert_safe_target_context "$tmp"
  preflight_seed_correct_links "$target"

  rm -f "$target/AGENTS.md"
  printf 'real file not link\n' > "$target/AGENTS.md"

  run_cli out status verify --target "$target"
  assert_exit_nonzero "$status" 'verify deve falhar com arquivo real no lugar do link'
  assert_contains "$out" 'conflict' 'verify deve reportar conflict para arquivo real'
  assert_contains "$out" 'AGENTS.md' 'verify conflict deve citar AGENTS.md'

  rm -rf "$tmp"
}

preflight_install_empty_applies() {
  local tmp target out status link_count

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  mkdir -p "$target"
  assert_safe_target_context "$tmp"

  run_cli out status install --target "$target"
  assert_exit_zero "$status" 'install em destino vazio deve passar'
  link_count=$(find "$target" -type l | wc -l)
  [ "$link_count" -eq 78 ] || fail 'install T5 deve criar os links após preflight'

  rm -rf "$tmp"
}

preflight_install_local_only_ready() {
  local tmp target out status

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  mkdir -p "$target/node_modules/x"
  assert_safe_target_context "$tmp"
  printf 'SECRET=1\n' > "$target/.env"
  printf 'm\n' > "$target/node_modules/x/a.js"

  run_cli out status install --target "$target"
  assert_exit_zero "$status" 'install com só local-only deve passar no preflight'
  [ -f "$target/.env" ] || fail 'install preflight removeu .env'
  [ -f "$target/node_modules/x/a.js" ] || fail 'install preflight removeu node_modules'
  [ -L "$target/AGENTS.md" ] || fail 'install T5 deve criar AGENTS.md'

  rm -rf "$tmp"
}

preflight_install_replace_classifies_not_applies() {
  local tmp target backup out status backup_file expected

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  backup="$tmp/backup"
  mkdir -p "$target" "$backup"
  assert_safe_target_context "$tmp"
  printf 'old\n' > "$target/AGENTS.md"

  run_cli out status install --target "$target" --replace --backup-dir "$backup"
  assert_exit_zero "$status" 'install --replace com conflict file deve substituir com backup'
  assert_contains "$out" 'installed' 'replace autorizado deve reportar instalação'
  [ -L "$target/AGENTS.md" ] || fail 'AGENTS.md deve virar symlink gerenciado'
  expected=$(readlink -f -- "$CONFIG_ROOT/AGENTS.md")
  [ "$(readlink -- "$target/AGENTS.md")" = "$expected" ] || fail 'symlink AGENTS.md aponta para origem errada'
  backup_file=$(find "$backup" -type f -name 'AGENTS.md' -print -quit)
  [ -n "$backup_file" ] || fail 'backup deve conter AGENTS.md anterior'
  [ "$(cat "$backup_file")" = 'old' ] || fail 'backup de AGENTS.md deve preservar conteúdo anterior'

  run_cli out status verify --target "$target"
  assert_exit_zero "$status" 'verify deve passar após replace autorizado'

  rm -rf "$tmp"
}

preflight() {
  preflight_multiple_divergences_reported
  preflight_install_conflicts_no_mutate
  preflight_verify_correct_full_install
  preflight_verify_unknown_fails
  preflight_verify_local_only_allowed
  preflight_verify_broken_and_wrong_target
  preflight_verify_real_file_conflict
  preflight_install_empty_applies
  preflight_install_local_only_ready
  preflight_install_replace_classifies_not_applies

  printf 'PASS: preflight\n'
}

# --- T5: instalação limpa, estado atômico e idempotência ---------------------

install_assert_links_and_real_containers() {
  local target=$1 path dest expected parent link_count

  link_count=$(find "$target" -type l | wc -l)
  [ "$link_count" -eq 78 ] || fail "instalação limpa deve criar 78 symlinks; encontrados: $link_count"
  while IFS= read -r path || [ -n "$path" ]; do
    dest="$target/$path"
    expected=$(readlink -f -- "$CONFIG_ROOT/$path")
    [ -L "$dest" ] || fail "managed não é symlink: $path"
    [ "$(readlink -- "$dest")" = "$expected" ] || fail "symlink não usa origem física absoluta exata: $path"
    parent=$(dirname -- "$dest")
    while [ "$parent" != "$target" ]; do
      [ -d "$parent" ] || fail "container não é diretório: $parent"
      [ ! -L "$parent" ] || fail "container não pode ser symlink: $parent"
      parent=$(dirname -- "$parent")
    done
  done < "$MANAGED_MANIFEST"
}

install_expected_state() {
  local canonical_root path
  canonical_root=$(CDPATH= cd -- "$1" && pwd -P)
  printf 'format=1\ncanonical_root=%s\n' "$canonical_root"
  while IFS= read -r path || [ -n "$path" ]; do
    printf 'link=%s\n' "$path"
  done < "$MANAGED_MANIFEST"
}

install_clean_missing_target_verify_state_and_noop() {
  local tmp target out status expected_state actual_state fp_before fp_after mode temp_residual

  tmp=$(mktemp -d)
  target="$tmp/target absent initially"
  assert_safe_target_context "$tmp"
  [ ! -e "$target" ] || fail 'fixture exige target inicialmente ausente'

  run_cli out status install --target "$target"
  assert_exit_zero "$status" 'instalação limpa com target ausente deve passar'
  assert_contains "$out" 'installed' 'instalação limpa deve reportar sucesso'
  [ -d "$target" ] && [ ! -L "$target" ] || fail 'target deve ser diretório real criado'
  install_assert_links_and_real_containers "$target"

  run_cli out status verify --target "$target"
  assert_exit_zero "$status" 'verify deve passar após clean install'

  expected_state=$(install_expected_state "$CONFIG_ROOT")
  actual_state=$(<"$target/.opencode-config-state")
  [ "$actual_state" = "$expected_state" ] || fail 'estado não é determinístico ou difere do formato esperado'
  mode=$(stat -c '%a' -- "$target/.opencode-config-state")
  [ "$mode" = 600 ] || fail "estado deve ter modo 600; encontrado: $mode"
  temp_residual=$(find "$target" -maxdepth 1 -name '.opencode-config-state.tmp.*' -print -quit)
  [ -z "$temp_residual" ] || fail 'arquivo temporário do estado permaneceu após sucesso'

  fp_before=$(install_fingerprint "$target")
  sleep 1
  run_cli out status install --target "$target"
  assert_exit_zero "$status" 'segunda instalação correta deve passar'
  assert_contains "$out" 'already correct' 'segunda instalação deve reportar no-op'
  fp_after=$(install_fingerprint "$target")
  [ "$fp_before" = "$fp_after" ] || fail 'segunda instalação alterou metadata, links ou estado'

  rm -rf "$tmp"
}

install_immediate_effect_from_fixture() {
  local tmp fixture_config target out status marker

  tmp=$(mktemp -d)
  fixture_config="$tmp/canonical config with spaces"
  target="$tmp/active config"
  cp -R "$CONFIG_ROOT" "$fixture_config"
  assert_safe_target_context "$tmp"

  run_cli_with_config_root out status "$fixture_config" install --target "$target"
  assert_exit_zero "$status" 'install com fonte canônica fixture deve passar'
  marker='fixture-change-observed-immediately'
  printf '%s\n' "$marker" >> "$fixture_config/AGENTS.md"
  [ "$(tail -n 1 -- "$target/AGENTS.md")" = "$marker" ] || fail 'mudança canônica não apareceu imediatamente no destino'

  rm -rf "$tmp"
}

install_preserves_local_only_and_manages_state() {
  local tmp target out status env_before env_after modules_before modules_after state

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  mkdir -p "$target/node_modules/pkg"
  assert_safe_target_context "$tmp"
  printf 'SECRET=do-not-read-in-production\n' > "$target/.env"
  printf 'dependency\n' > "$target/node_modules/pkg/index.js"
  printf 'local ignore\n' > "$target/.gitignore"
  env_before=$(sha256sum -- "$target/.env" | awk '{print $1}')
  modules_before=$(sha256sum -- "$target/node_modules/pkg/index.js" | awk '{print $1}')

  run_cli out status install --target "$target"
  assert_exit_zero "$status" 'install deve aceitar e preservar local-only'
  env_after=$(sha256sum -- "$target/.env" | awk '{print $1}')
  modules_after=$(sha256sum -- "$target/node_modules/pkg/index.js" | awk '{print $1}')
  [ "$env_before" = "$env_after" ] || fail '.env foi alterado'
  [ "$modules_before" = "$modules_after" ] || fail 'node_modules foi alterado'
  [ "$(<"$target/.gitignore")" = 'local ignore' ] || fail '.gitignore local foi alterado'
  state=$(<"$target/.opencode-config-state")
  assert_contains "$state" 'format=1' 'estado local deve ser gerenciado/atualizado'
  case "$state" in
    *'.env'*|*'node_modules'*) fail 'estado não pode registrar conteúdo local-only' ;;
  esac

  rm -rf "$tmp"
}

install_blockers_and_symlink_container_are_zero_mutation() {
  local tmp target out status before after

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  mkdir -p "$target"
  assert_safe_target_context "$tmp"
  printf 'conflict\n' > "$target/AGENTS.md"
  printf 'unknown\n' > "$target/custom.conf"
  before=$(install_fingerprint "$target")
  run_cli out status install --target "$target"
  assert_exit_nonzero "$status" 'conflict/unknown deve bloquear install'
  after=$(install_fingerprint "$target")
  [ "$before" = "$after" ] || fail 'blockers causaram mutação'
  rm -rf "$tmp"

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  mkdir -p "$target" "$tmp/foreign-agents"
  assert_safe_target_context "$tmp"
  ln -s "$tmp/foreign-agents" "$target/agents"
  before=$(install_fingerprint "$target")
  run_cli out status install --target "$target"
  assert_exit_nonzero "$status" 'container symlink deve bloquear install'
  after=$(install_fingerprint "$target")
  [ "$before" = "$after" ] || fail 'container symlink bloqueante causou mutação'
  rm -rf "$tmp"
}

install_replace_is_deferred_without_mutation() {
  local tmp target backup out status backup_file expected mode run_dir fp_before fp_after

  tmp=$(mktemp -d)
  target="$tmp/target with spaces"
  backup="$tmp/backup with spaces"
  mkdir -p "$target" "$backup"
  assert_safe_target_context "$tmp"
  printf 'keep-me\n' > "$target/AGENTS.md"

  run_cli out status install --target "$target" --replace --backup-dir "$backup"
  assert_exit_zero "$status" '--replace com paths espaçados deve aplicar substituição'
  assert_contains "$out" 'installed' 'replace com espaços deve reportar instalação'
  [ -L "$target/AGENTS.md" ] || fail 'replace deve publicar symlink em path com espaços'
  expected=$(readlink -f -- "$CONFIG_ROOT/AGENTS.md")
  [ "$(readlink -- "$target/AGENTS.md")" = "$expected" ] || fail 'symlink final incorreto após replace'
  backup_file=$(find "$backup" -type f -name 'AGENTS.md' -print -quit)
  [ -n "$backup_file" ] || fail 'backup deve existir sob backup-dir com espaços'
  [ "$(cat "$backup_file")" = 'keep-me' ] || fail 'backup deve preservar conteúdo conflitante'
  run_dir=$(find "$backup" -mindepth 1 -maxdepth 1 -type d -print -quit)
  [ -n "$run_dir" ] || fail 'backup deve usar subdiretório exclusivo de execução'
  mode=$(stat -c '%a' -- "$run_dir")
  [ "$mode" = 700 ] || fail "subdiretório de backup deve ter modo 700; encontrado: $mode"

  fp_before=$(install_fingerprint "$target")
  run_cli out status install --target "$target"
  assert_exit_zero "$status" 'segunda instalação sem conflitos deve ser idempotente'
  assert_contains "$out" 'already correct' 'segunda install deve ser no-op'
  fp_after=$(install_fingerprint "$target")
  [ "$fp_before" = "$fp_after" ] || fail 'install idempotente alterou fingerprint'

  rm -rf "$tmp"
}

install_rejects_final_destination_swap_without_escape() {
  local tmp target external out status escaped

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  external="$tmp/external directory"
  mkdir -p "$target" "$external"
  assert_safe_target_context "$tmp"

  run_cli_with_internal_hook out status link-final "$target" "$external" \
    install --target "$target"
  assert_exit_nonzero "$status" 'troca do destino final antes da publicação deve falhar'
  escaped=$(find "$external" -mindepth 1 -print -quit)
  [ -z "$escaped" ] || fail 'publicação seguiu symlink final e criou arquivo fora do target'

  rm -rf "$tmp"
}

install_rejects_container_swap_without_escape() {
  local tmp target external out status escaped

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  external="$tmp/external container"
  mkdir -p "$target" "$external"
  assert_safe_target_context "$tmp"

  run_cli_with_internal_hook out status link-container "$target" "$external" \
    install --target "$target"
  assert_exit_nonzero "$status" 'troca do container antes da publicação deve falhar'
  escaped=$(find "$external" -mindepth 1 -print -quit)
  [ -z "$escaped" ] || fail 'publicação atravessou container trocado e escapou do target'

  rm -rf "$tmp"
}

install_cleans_link_if_container_moves_after_last_check() {
  local tmp target external out status escaped

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  external="$tmp/outside"
  mkdir -p "$target" "$external"
  assert_safe_target_context "$tmp"

  run_cli_with_internal_hook out status link-container-after-check "$target" "$external" \
    install --target "$target"
  assert_exit_nonzero "$status" 'container movido após última check deve falhar'
  escaped=$(find "$external" -type l -print -quit)
  [ -z "$escaped" ] || fail 'link publicado via dirfd permaneceu fora do target após detecção'

  rm -rf "$tmp"
}

install_rejects_state_swap_without_external_chmod() {
  local tmp target external_file out status mode

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  external_file="$tmp/external-state-target"
  mkdir -p "$target"
  assert_safe_target_context "$tmp"
  printf 'external\n' > "$external_file"
  chmod 640 -- "$external_file"

  run_cli_with_internal_hook out status state-file "$target" "$external_file" \
    install --target "$target"
  assert_exit_nonzero "$status" 'state surgido antes da publicação no-clobber deve falhar'
  mode=$(stat -c '%a' -- "$external_file")
  [ "$mode" = 640 ] || fail "chmod de state seguiu symlink e alterou arquivo externo para $mode"

  rm -rf "$tmp"
}

install_rejects_state_publish_swap_without_escape() {
  local tmp target external out status escaped

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  external="$tmp/external-state-directory"
  mkdir -p "$target" "$external"
  assert_safe_target_context "$tmp"

  run_cli_with_internal_hook out status state-dir "$target" "$external" \
    install --target "$target"
  assert_exit_nonzero "$status" 'state trocado antes do rename deve falhar'
  escaped=$(find "$external" -mindepth 1 -print -quit)
  [ -z "$escaped" ] || fail 'rename de state seguiu symlink para diretório externo'
  escaped=$(find "$target" -maxdepth 1 -name '.opencode-config-state.tmp.*' -print -quit)
  [ -z "$escaped" ] || fail 'falha segura de state deixou temporário residual'

  rm -rf "$tmp"
}

install_cleans_state_if_target_moves_before_temp() {
  local tmp target external out status escaped

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  external="$tmp/outside-state"
  mkdir -p "$target" "$external"
  assert_safe_target_context "$tmp"

  run_cli_with_internal_hook out status state-target-after-check "$target" "$external" \
    install --target "$target"
  assert_exit_nonzero "$status" 'target movido no intervalo pré-temp deve falhar'
  escaped=$(find "$external" \( -name '.opencode-config-state' -o -name '.opencode-config-state.tmp.*' \) -print -quit)
  [ -z "$escaped" ] || fail 'state/temp persistiu fora do target após movimento do dirfd'

  rm -rf "$tmp"
}

install_does_not_overwrite_preexisting_different_state() {
  local tmp target out status before after target_item

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  mkdir -p "$target"
  assert_safe_target_context "$tmp"
  printf 'foreign-state-must-survive\n' > "$target/.opencode-config-state"
  before=$(sha256sum -- "$target/.opencode-config-state" | awk '{print $1}')

  run_cli out status install --target "$target"
  assert_exit_nonzero "$status" 'state preexistente divergente deve bloquear T5'
  after=$(sha256sum -- "$target/.opencode-config-state" | awk '{print $1}')
  [ "$before" = "$after" ] || fail 'state preexistente divergente foi sobrescrito'
  target_item=$(find "$target" -mindepth 1 ! -name '.opencode-config-state' -print -quit)
  [ -z "$target_item" ] || fail 'state divergente deveria bloquear antes da criação de links'

  rm -rf "$tmp"
}

install_rejects_intermediate_source_symlink_escape() {
  local tmp fixture_config external target out status target_item

  tmp=$(mktemp -d)
  fixture_config="$tmp/config fixture"
  external="$tmp/external canonical"
  target="$tmp/opencode"
  cp -R "$CONFIG_ROOT" "$fixture_config"
  mkdir -p "$external"
  cp "$CONFIG_ROOT/themes/min-dark.json" "$external/min-dark.json"
  rm -rf "$fixture_config/themes"
  ln -s "$external" "$fixture_config/themes"
  assert_safe_target_context "$tmp"

  run_cli_with_config_root out status "$fixture_config" install --target "$target"
  assert_exit_nonzero "$status" 'origem com symlink intermediário deve ser rejeitada'
  target_item=$(find "$target" -mindepth 1 -print -quit 2>/dev/null || true)
  [ -z "$target_item" ] || fail 'origem insegura causou mutação antes da rejeição'

  rm -rf "$tmp"
}

install_rejects_source_swap_after_validation() {
  local tmp fixture_config external target out status linked_external

  tmp=$(mktemp -d)
  fixture_config="$tmp/config fixture"
  external="$tmp/external canonical"
  target="$tmp/opencode"
  cp -R "$CONFIG_ROOT" "$fixture_config"
  mkdir -p "$external"
  cp "$CONFIG_ROOT/themes/min-dark.json" "$external/min-dark.json"
  assert_safe_target_context "$tmp"

  OCC_HOOK_CONFIG_ROOT="$fixture_config" \
    run_cli_with_internal_hook out status source-swap "$target" "$external" \
      install --target "$target"
  assert_exit_nonzero "$status" 'origem trocada após validação inicial deve falhar'
  linked_external=$(find "$target" -type l -lname "$external/*" -print -quit 2>/dev/null || true)
  [ -z "$linked_external" ] || fail 'path externo trocado após validação foi publicado'

  rm -rf "$tmp"
}

install() {
  install_clean_missing_target_verify_state_and_noop
  install_immediate_effect_from_fixture
  install_preserves_local_only_and_manages_state
  install_blockers_and_symlink_container_are_zero_mutation
  install_replace_is_deferred_without_mutation
  install_rejects_final_destination_swap_without_escape
  install_rejects_container_swap_without_escape
  install_cleans_link_if_container_moves_after_last_check
  install_rejects_state_swap_without_external_chmod
  install_rejects_state_publish_swap_without_escape
  install_cleans_state_if_target_moves_before_temp
  install_does_not_overwrite_preexisting_different_state
  install_rejects_intermediate_source_symlink_escape
  install_rejects_source_swap_after_validation
  printf 'PASS: install\n'
}

# --- T6: backup explícito e rollback transacional ----------------------------

rollback_find_backup_run() {
  local backup_root=$1
  find "$backup_root" -mindepth 1 -maxdepth 1 -type d -name 'opencode-config-backup-*' -print -quit
}

rollback_unauthorized_conflict_zero_mutation() {
  local tmp target out status before after

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  mkdir -p "$target"
  assert_safe_target_context "$tmp"
  printf 'human-agents\n' > "$target/AGENTS.md"
  before=$(install_fingerprint "$target")

  run_cli out status install --target "$target"
  assert_exit_nonzero "$status" 'conflito sem --replace deve abortar'
  assert_contains "$out" 'conflict' 'deve reportar conflict'
  after=$(install_fingerprint "$target")
  [ "$before" = "$after" ] || fail 'conflito não autorizado mutou o destino'
  [ "$(cat "$target/AGENTS.md")" = 'human-agents' ] || fail 'conteúdo conflitante foi alterado'

  rm -rf "$tmp"
}

rollback_replace_file_conflict_with_backup() {
  local tmp target backup out status backup_file expected run_dir mode

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  backup="$tmp/backup"
  mkdir -p "$target" "$backup"
  assert_safe_target_context "$tmp"
  printf 'previous-agents\n' > "$target/AGENTS.md"

  run_cli out status install --target "$target" --replace --backup-dir "$backup"
  assert_exit_zero "$status" 'replace de arquivo real deve passar'
  [ -L "$target/AGENTS.md" ] || fail 'destino deve ser symlink após replace'
  expected=$(readlink -f -- "$CONFIG_ROOT/AGENTS.md")
  [ "$(readlink -- "$target/AGENTS.md")" = "$expected" ] || fail 'symlink incorreto após replace de arquivo'
  run_dir=$(rollback_find_backup_run "$backup")
  [ -n "$run_dir" ] || fail 'deve criar subdir exclusivo de backup'
  mode=$(stat -c '%a' -- "$run_dir")
  [ "$mode" = 700 ] || fail "backup run dir mode=$mode (esperado 700)"
  backup_file="$run_dir/AGENTS.md"
  [ -f "$backup_file" ] || fail 'backup deve preservar AGENTS.md como arquivo'
  [ "$(cat "$backup_file")" = 'previous-agents' ] || fail 'conteúdo do backup diverge do original'
  [ ! -L "$backup_file" ] || fail 'backup de arquivo real não deve ser symlink'

  run_cli out status verify --target "$target"
  assert_exit_zero "$status" 'verify OK após replace de arquivo'

  rm -rf "$tmp"
}

rollback_replace_foreign_and_broken_links() {
  local tmp target backup out status run_dir expected raw

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  backup="$tmp/backup dir"
  mkdir -p "$target/themes" "$backup"
  assert_safe_target_context "$tmp"
  printf 'foreign-body\n' > "$tmp/foreign-origin.jsonc"
  ln -s "$tmp/foreign-origin.jsonc" "$target/opencode.jsonc"
  ln -s "$tmp/missing-canonical-theme.json" "$target/themes/min-dark.json"

  run_cli out status install --target "$target" --replace --backup-dir "$backup"
  assert_exit_zero "$status" 'replace de foreign/broken deve passar'
  expected=$(readlink -f -- "$CONFIG_ROOT/opencode.jsonc")
  [ "$(readlink -- "$target/opencode.jsonc")" = "$expected" ] || fail 'foreign não foi substituído pelo link correto'
  expected=$(readlink -f -- "$CONFIG_ROOT/themes/min-dark.json")
  [ "$(readlink -- "$target/themes/min-dark.json")" = "$expected" ] || fail 'broken não foi substituído pelo link correto'

  run_dir=$(rollback_find_backup_run "$backup")
  [ -n "$run_dir" ] || fail 'backup run ausente após replace de links'
  [ -L "$run_dir/opencode.jsonc" ] || fail 'backup de foreign deve registrar symlink'
  raw=$(readlink -- "$run_dir/opencode.jsonc")
  [ "$raw" = "$tmp/foreign-origin.jsonc" ] || fail "backup foreign text=$raw"
  [ -L "$run_dir/themes/min-dark.json" ] || fail 'backup de broken deve registrar symlink'
  raw=$(readlink -- "$run_dir/themes/min-dark.json")
  [ "$raw" = "$tmp/missing-canonical-theme.json" ] || fail "backup broken text=$raw"

  run_cli out status verify --target "$target"
  assert_exit_zero "$status" 'verify OK após replace de foreign/broken'

  rm -rf "$tmp"
}

rollback_replace_multiple_and_preserve_local_only() {
  local tmp target backup out status env_hash

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  backup="$tmp/backup"
  mkdir -p "$target/agents" "$backup"
  assert_safe_target_context "$tmp"
  printf 'a\n' > "$target/AGENTS.md"
  printf 'b\n' > "$target/opencode.jsonc"
  printf 'c\n' > "$target/agents/architect.md"
  printf 'SECRET=keep\n' > "$target/.env"
  env_hash=$(sha256sum -- "$target/.env" | awk '{print $1}')

  run_cli out status install --target "$target" --replace --backup-dir "$backup"
  assert_exit_zero "$status" 'múltiplos replaceables em uma execução devem passar'
  [ -L "$target/AGENTS.md" ] && [ -L "$target/opencode.jsonc" ] && [ -L "$target/agents/architect.md" ] \
    || fail 'todos os conflitos devem virar symlinks'
  [ -f "$target/.env" ] || fail 'local-only .env foi removido'
  [ "$(sha256sum -- "$target/.env" | awk '{print $1}')" = "$env_hash" ] || fail '.env foi alterado'
  [ -f "$(find "$backup" -type f -name 'AGENTS.md' -print -quit)" ] || fail 'backup AGENTS.md ausente'
  [ -f "$(find "$backup" -type f -name 'opencode.jsonc' -print -quit)" ] || fail 'backup opencode.jsonc ausente'
  [ -f "$(find "$backup" -type f -name 'architect.md' -print -quit)" ] || fail 'backup architect.md ausente'

  run_cli out status verify --target "$target"
  assert_exit_zero "$status" 'verify OK após múltiplos replaces'

  rm -rf "$tmp"
}

rollback_unknown_blocks_even_with_replace() {
  local tmp target backup out status before after

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  backup="$tmp/backup"
  mkdir -p "$target" "$backup"
  assert_safe_target_context "$tmp"
  printf 'conflict\n' > "$target/AGENTS.md"
  printf 'human-unknown\n' > "$target/custom-settings.conf"
  before=$(install_fingerprint "$target")

  run_cli out status install --target "$target" --replace --backup-dir "$backup"
  assert_exit_nonzero "$status" 'unknown deve bloquear mesmo com --replace'
  assert_contains "$out" 'unknown' 'deve reportar unknown'
  after=$(install_fingerprint "$target")
  [ "$before" = "$after" ] || fail 'unknown+replace mutou o destino'
  [ "$(cat "$target/AGENTS.md")" = 'conflict' ] || fail 'conflict foi alterado apesar do bloqueio por unknown'
  [ -z "$(find "$backup" -mindepth 1 -print -quit)" ] || fail 'backup não deve ser escrito quando unknown bloqueia'

  rm -rf "$tmp"
}

rollback_backup_failure_no_target_mutation() {
  local tmp target backup out status before after

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  backup="$tmp/backup-ro"
  mkdir -p "$target" "$backup"
  assert_safe_target_context "$tmp"
  printf 'stay\n' > "$target/AGENTS.md"
  before=$(install_fingerprint "$target")

  # Hook força falha de backup antes de qualquer remoção.
  run_cli_with_internal_hook out status backup-fail "$target" "$backup" \
    install --target "$target" --replace --backup-dir "$backup"
  assert_exit_nonzero "$status" 'falha de backup deve abortar'
  after=$(install_fingerprint "$target")
  [ "$before" = "$after" ] || fail 'falha de backup mutou o target'
  [ "$(cat "$target/AGENTS.md")" = 'stay' ] || fail 'conteúdo original perdido em falha de backup'
  [ ! -L "$target/AGENTS.md" ] || fail 'symlink não deve existir após falha de backup'

  # backup-dir não gravável: zero mutação no target
  chmod a-w "$backup"
  run_cli out status install --target "$target" --replace --backup-dir "$backup"
  assert_exit_nonzero "$status" 'backup-dir não gravável deve falhar'
  after=$(install_fingerprint "$target")
  [ "$before" = "$after" ] || fail 'backup-dir RO mutou o target'
  chmod u+w "$backup"

  rm -rf "$tmp"
}

rollback_mid_apply_restores_and_preserves_ok_links() {
  local tmp target backup out status expected_ok agents_content

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  backup="$tmp/backup"
  mkdir -p "$target" "$backup"
  assert_safe_target_context "$tmp"

  # Pré-instala links corretos; depois introduz conflitos em paths managed.
  preflight_seed_correct_links "$target"
  expected_ok=$(readlink -- "$target/opencode.jsonc")
  rm -f "$target/AGENTS.md" "$target/agents/architect.md" "$target/themes/min-dark.json"
  printf 'conflict-agents\n' > "$target/AGENTS.md"
  printf 'conflict-architect\n' > "$target/agents/architect.md"
  printf 'conflict-theme\n' > "$target/themes/min-dark.json"
  # Local-only permanece
  printf 'SECRET=1\n' > "$target/.env"

  # Falha após 2 mutações bem-sucedidas (replaces/creates desta execução).
  run_cli_with_internal_hook out status mid-apply-fail "$target" 2 \
    install --target "$target" --replace --backup-dir "$backup"
  assert_exit_nonzero "$status" 'falha intermediária deve sair non-zero'

  # Conteúdos substituídos nesta run devem ser restaurados.
  [ ! -L "$target/AGENTS.md" ] || fail 'AGENTS.md não deve permanecer como link desta run após rollback'
  agents_content=$(cat "$target/AGENTS.md" 2>/dev/null || true)
  [ "$agents_content" = 'conflict-agents' ] || fail "AGENTS.md não restaurado (got=$agents_content)"
  [ -f "$target/agents/architect.md" ] || [ -f "$target/themes/min-dark.json" ] \
    || fail 'ao menos um conflito restaurado esperado'
  # Se o path foi mutado nesta run, conteúdo original deve voltar:
  if [ -f "$target/agents/architect.md" ]; then
    [ "$(cat "$target/agents/architect.md")" = 'conflict-architect' ] \
      || fail 'architect.md não restaurado'
  fi
  if [ -f "$target/themes/min-dark.json" ]; then
    [ "$(cat "$target/themes/min-dark.json")" = 'conflict-theme' ] \
      || fail 'theme não restaurado'
  fi

  # Link preexistente correto (não parte das mutações de replace desta fixture
  # se não foi tocado) — opencode.jsonc permaneceu ok e não deve ser removido.
  [ -L "$target/opencode.jsonc" ] || fail 'link ok preexistente foi removido no rollback'
  [ "$(readlink -- "$target/opencode.jsonc")" = "$expected_ok" ] \
    || fail 'link ok preexistente foi alterado no rollback'
  [ -f "$target/.env" ] || fail 'local-only removido no rollback'
  [ "$(cat "$target/.env")" = 'SECRET=1' ] || fail 'local-only alterado no rollback'

  # Backup permanece para forense
  [ -n "$(rollback_find_backup_run "$backup")" ] || fail 'backup run deve permanecer após rollback'

  rm -rf "$tmp"
}

rollback_backup_dir_rejects_symlink() {
  local tmp target backup_link real_backup out status before

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  real_backup="$tmp/real-backup"
  backup_link="$tmp/backup-link"
  mkdir -p "$target" "$real_backup"
  ln -s "$real_backup" "$backup_link"
  assert_safe_target_context "$tmp"
  printf 'x\n' > "$target/AGENTS.md"
  before=$(install_fingerprint "$target")

  run_cli out status install --target "$target" --replace --backup-dir "$backup_link"
  assert_exit_nonzero "$status" 'backup-dir symlink deve ser rejeitado'
  [ "$(install_fingerprint "$target")" = "$before" ] || fail 'backup-dir symlink mutou target'

  rm -rf "$tmp"
}

rollback_paths_with_spaces() {
  local tmp target backup out status backup_file

  tmp=$(mktemp -d)
  target="$tmp/dest with spaces/opencode"
  backup="$tmp/back up dir"
  mkdir -p "$target" "$backup"
  assert_safe_target_context "$tmp"
  printf 'spaced\n' > "$target/AGENTS.md"

  run_cli out status install --target "$target" --replace --backup-dir "$backup"
  assert_exit_zero "$status" 'replace com espaços deve passar'
  backup_file=$(find "$backup" -type f -name 'AGENTS.md' -print -quit)
  [ -n "$backup_file" ] || fail 'backup com espaços deve conter AGENTS.md'
  [ "$(cat "$backup_file")" = 'spaced' ] || fail 'backup com espaços perdeu conteúdo'

  run_cli out status verify --target "$target"
  assert_exit_zero "$status" 'verify com espaços após replace'

  rm -rf "$tmp"
}

# Sourceia a lib num subshell isolado e avalia o body (journal sintético AC-09/EC-09).
# Uso: rollback_lib_eval TMPDIR 'OCC_TARGET=...; ...; opencode_config_rollback'
# Exit status do body é propagado.
rollback_lib_eval() {
  local tmp=$1
  local body=$2
  assert_safe_target_context "$tmp"
  (
    set -euo pipefail
    # shellcheck source=lib/opencode-config.sh
    . "$REPO_ROOT/lib/opencode-config.sh"
    eval "$body"
  )
}

# Journal só com backup|* + original ainda no dest + backup apagado:
# rollback NÃO pode apagar o original (falha entre backup journal e remove).
rollback_missing_backup_preserves_original_at_dest() {
  local tmp target backup_path status

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  mkdir -p "$target" "$tmp/backup-run"
  assert_safe_target_context "$tmp"
  printf 'original-must-survive\n' > "$target/AGENTS.md"
  backup_path="$tmp/backup-run/AGENTS.md"
  # Simula backup journalado e depois destruído (disco/FS).
  printf 'original-must-survive\n' > "$backup_path"
  rm -f -- "$backup_path"

  set +e
  rollback_lib_eval "$tmp" "
    OCC_TARGET=$(printf '%q' "$target")
    opencode_config_journal_reset
    OCC_JOURNAL=(\"backup|AGENTS.md|$(printf '%q' "$backup_path")\")
    opencode_config_rollback
  "
  status=$?
  set -e

  [ -f "$target/AGENTS.md" ] || fail 'rollback apagou original quando backup ausente (AC-09)'
  [ ! -L "$target/AGENTS.md" ] || fail 'original virou symlink indevidamente'
  [ "$(cat "$target/AGENTS.md")" = 'original-must-survive' ] \
    || fail 'conteúdo original destruído com backup ausente'
  # Não pode engolir falha de restore de conteúdo pré-existente.
  [ "$status" -ne 0 ] || fail 'rollback com backup ausente deve falhar de forma audível'

  rm -rf "$tmp"
}

# backup+removed+created_link com backup apagado: pode remover link desta run,
# não pode reivindicar sucesso nem destruir conteúdo não relacionado.
rollback_missing_backup_after_replace_fails_loud() {
  local tmp target backup_path status unrelated

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  mkdir -p "$target" "$tmp/backup-run"
  assert_safe_target_context "$tmp"
  # Resíduo desta run: symlink publicado após remove do original.
  ln -s /etc/hosts "$target/AGENTS.md"
  printf 'keep-me\n' > "$target/unrelated-local.txt"
  unrelated=$(sha256sum -- "$target/unrelated-local.txt" | awk '{print $1}')
  backup_path="$tmp/backup-run/AGENTS.md"
  # Backup journalado mas material ausente.
  : > "$backup_path"
  rm -f -- "$backup_path"

  set +e
  rollback_lib_eval "$tmp" "
    OCC_TARGET=$(printf '%q' "$target")
    opencode_config_journal_reset
    OCC_JOURNAL=(
      \"backup|AGENTS.md|$(printf '%q' "$backup_path")\"
      \"removed|AGENTS.md|file\"
      \"created_link|AGENTS.md\"
    )
    opencode_config_rollback
  "
  status=$?
  set -e

  [ "$status" -ne 0 ] || fail 'rollback sem backup após replace deve falhar (não claim success)'
  # Link desta run pode ser removido; não deve restar como "instalação ok".
  if [ -L "$target/AGENTS.md" ]; then
    fail 'symlink desta run não deveria permanecer como sucesso silencioso'
  fi
  # Não inventar destruição de conteúdo não relacionado.
  [ -f "$target/unrelated-local.txt" ] || fail 'rollback destruiu arquivo não relacionado'
  [ "$(sha256sum -- "$target/unrelated-local.txt" | awk '{print $1}')" = "$unrelated" ] \
    || fail 'conteúdo não relacionado foi alterado no rollback'
  # Não deve fabricar um diretório no lugar do managed path sem restore.
  if [ -d "$target/AGENTS.md" ] && [ ! -L "$target/AGENTS.md" ]; then
    fail 'rollback não deve criar dir placeholder no lugar do original'
  fi

  rm -rf "$tmp"
}

# state_replaced com backup ausente: se o state antigo ainda está no dest
# (falha entre journal e replace), NÃO apagar deixando state MISSING.
rollback_state_replaced_missing_backup_preserves_state() {
  local tmp target backup_path status

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  mkdir -p "$target" "$tmp/backup-run"
  assert_safe_target_context "$tmp"
  printf 'format=1\nold-state\n' > "$target/.opencode-config-state"
  chmod 600 "$target/.opencode-config-state"
  backup_path="$tmp/backup-run/.opencode-config-state"
  printf 'format=1\nold-state\n' > "$backup_path"
  rm -f -- "$backup_path"

  set +e
  rollback_lib_eval "$tmp" "
    OCC_TARGET=$(printf '%q' "$target")
    opencode_config_journal_reset
    OCC_JOURNAL=(\"state_replaced|$(printf '%q' "$backup_path")\")
    opencode_config_rollback
  "
  status=$?
  set -e

  [ -f "$target/.opencode-config-state" ] \
    || fail 'state_replaced com backup ausente não pode deixar state MISSING'
  [ ! -L "$target/.opencode-config-state" ] || fail 'state virou symlink indevidamente'
  [ "$(cat "$target/.opencode-config-state")" = $'format=1\nold-state' ] \
    || fail 'conteúdo do state pré-existente foi destruído'
  [ "$status" -ne 0 ] || fail 'state_replaced sem backup deve falhar de forma audível'

  rm -rf "$tmp"
}

# cleanup não pode apagar run dir que já tem backup|* (falha pós-backup pré-remove).
rollback_cleanup_keeps_backup_run_with_backup_entries() {
  local tmp target run_dir marker

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  run_dir="$tmp/backup-parent/opencode-config-backup-TESTXX"
  mkdir -p "$target" "$run_dir"
  assert_safe_target_context "$tmp"
  printf 'precious\n' > "$run_dir/AGENTS.md"
  marker="$run_dir/AGENTS.md"

  rollback_lib_eval "$tmp" "
    OCC_TARGET=$(printf '%q' "$target")
    opencode_config_journal_reset
    OCC_BACKUP_RUN=$(printf '%q' "$run_dir")
    OCC_JOURNAL=(\"backup|AGENTS.md|$(printf '%q' "$run_dir/AGENTS.md")\")
    opencode_config_cleanup_unused_backup_run
    if [ -n \"\${OCC_BACKUP_RUN:-}\" ] && [ -d \"\$OCC_BACKUP_RUN\" ]; then
      printf 'kept\n' > $(printf '%q' "$tmp/cleanup-result")
    else
      printf 'wiped\n' > $(printf '%q' "$tmp/cleanup-result")
    fi
  "

  [ -f "$marker" ] || fail 'cleanup apagou material de backup journalado (backup|*)'
  [ "$(cat "$marker")" = 'precious' ] || fail 'conteúdo do backup foi perdido no cleanup'
  [ -d "$run_dir" ] || fail 'backup run dir com backup|* foi removido'
  [ "$(cat "$tmp/cleanup-result")" = 'kept' ] \
    || fail "cleanup deveria manter run com backup|* (got=$(cat "$tmp/cleanup-result" 2>/dev/null || echo missing))"

  rm -rf "$tmp"
}

# cleanup ainda remove run vazio sem qualquer backup/mutação (regressão positiva).
rollback_cleanup_removes_truly_unused_empty_run() {
  local tmp target run_dir

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  run_dir="$tmp/backup-parent/opencode-config-backup-EMPTY01"
  mkdir -p "$target" "$run_dir"
  assert_safe_target_context "$tmp"

  rollback_lib_eval "$tmp" "
    OCC_TARGET=$(printf '%q' "$target")
    opencode_config_journal_reset
    OCC_BACKUP_RUN=$(printf '%q' "$run_dir")
    OCC_JOURNAL=()
    opencode_config_cleanup_unused_backup_run
    if [ -z \"\${OCC_BACKUP_RUN:-}\" ] && [ ! -d $(printf '%q' "$run_dir") ]; then
      printf 'wiped\n' > $(printf '%q' "$tmp/cleanup-result")
    else
      printf 'kept\n' > $(printf '%q' "$tmp/cleanup-result")
    fi
  "

  [ ! -d "$run_dir" ] || fail 'run vazio sem journal deveria ser removido'
  [ "$(cat "$tmp/cleanup-result")" = 'wiped' ] || fail 'cleanup deveria limpar run unused vazio'

  rm -rf "$tmp"
}

rollback() {
  rollback_unauthorized_conflict_zero_mutation
  rollback_replace_file_conflict_with_backup
  rollback_replace_foreign_and_broken_links
  rollback_replace_multiple_and_preserve_local_only
  rollback_unknown_blocks_even_with_replace
  rollback_backup_failure_no_target_mutation
  rollback_mid_apply_restores_and_preserves_ok_links
  rollback_backup_dir_rejects_symlink
  rollback_paths_with_spaces
  rollback_missing_backup_preserves_original_at_dest
  rollback_missing_backup_after_replace_fails_loud
  rollback_state_replaced_missing_backup_preserves_state
  rollback_cleanup_keeps_backup_run_with_backup_entries
  rollback_cleanup_removes_truly_unused_empty_run

  printf 'PASS: rollback\n'
}

# --- T7: desinstalação condicionada à prova de propriedade -------------------

uninstall_valid_state_preserves_local_and_unknown_content() {
  local tmp target out status

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  assert_safe_target_context "$tmp"

  run_cli out status install --target "$target"
  assert_exit_zero "$status" 'fixture de uninstall deve instalar primeiro'
  printf 'SECRET=keep\n' > "$target/.env"
  printf 'human unknown\n' > "$target/custom.conf"
  printf 'local agent\n' > "$target/agents/local.md"

  run_cli out status uninstall --target "$target"
  assert_exit_zero "$status" 'uninstall com state e links válidos deve passar'
  assert_contains "$out" 'uninstalled' 'uninstall válido deve reportar sucesso'
  [ -z "$(find "$target" -type l -print -quit)" ] || fail 'uninstall removeu links fora da prova esperada'
  [ ! -e "$target/.opencode-config-state" ] || fail 'state válido permaneceu após uninstall'
  [ -f "$target/.env" ] || fail '.env local foi removido pelo uninstall'
  [ -f "$target/custom.conf" ] || fail 'unknown foi removido pelo uninstall'
  [ -f "$target/agents/local.md" ] || fail 'conteúdo local em container foi removido'
  [ -d "$target/agents" ] || fail 'container não vazio foi removido'
  [ -d "$target" ] && [ ! -L "$target" ] || fail 'target deve permanecer diretório real'

  rm -rf "$tmp"
}

uninstall_absent_target_is_noop() {
  local tmp target out status

  tmp=$(mktemp -d)
  target="$tmp/does-not-exist"
  assert_safe_target_context "$tmp"

  run_cli out status uninstall --target "$target"
  assert_exit_zero "$status" 'uninstall de target ausente deve ser no-op seguro'
  assert_contains "$out" 'already absent' 'uninstall ausente deve reportar no-op'
  [ ! -e "$target" ] || fail 'uninstall de target ausente criou estado ou diretório'

  rm -rf "$tmp"
}

uninstall_refuses_absent_or_corrupt_state_without_mutation() {
  local tmp target out status before after

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  assert_safe_target_context "$tmp"
  run_cli out status install --target "$target"
  assert_exit_zero "$status" 'fixture de state ausente deve instalar'
  rm -f -- "$target/.opencode-config-state"
  before=$(install_fingerprint "$target")

  run_cli out status uninstall --target "$target"
  assert_exit_nonzero "$status" 'uninstall sem state não pode reivindicar propriedade'
  assert_contains "$out" 'state' 'falha sem state deve mencionar state'
  after=$(install_fingerprint "$target")
  [ "$before" = "$after" ] || fail 'state ausente permitiu mutação no target'
  [ -L "$target/AGENTS.md" ] || fail 'link foi removido sem state de prova'

  printf 'format=1\ncorrupt\n' > "$target/.opencode-config-state"
  chmod 600 -- "$target/.opencode-config-state"
  before=$(install_fingerprint "$target")
  run_cli out status uninstall --target "$target"
  assert_exit_nonzero "$status" 'uninstall com state corrompido deve falhar'
  after=$(install_fingerprint "$target")
  [ "$before" = "$after" ] || fail 'state corrompido permitiu mutação no target'
  [ -f "$target/.opencode-config-state" ] || fail 'state corrompido foi removido'

  rm -rf "$tmp"
}

uninstall_refuses_divergent_literal_and_preserves_everything() {
  local tmp target out status before after

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  assert_safe_target_context "$tmp"
  run_cli out status install --target "$target"
  assert_exit_zero "$status" 'fixture de destino literal deve instalar'
  rm -f -- "$target/AGENTS.md"
  # Mesmo alvo físico, mas texto literal diferente: não há prova suficiente.
  ln -s -- "$CONFIG_ROOT/./AGENTS.md" "$target/AGENTS.md"
  before=$(install_fingerprint "$target")

  run_cli out status uninstall --target "$target"
  assert_exit_nonzero "$status" 'uninstall deve recusar destino literal divergente'
  assert_contains "$out" 'diverg' 'falha de propriedade deve informar divergência'
  after=$(install_fingerprint "$target")
  [ "$before" = "$after" ] || fail 'destino literal divergente permitiu mutação parcial'
  [ -L "$target/AGENTS.md" ] || fail 'link divergente foi removido'
  [ -f "$target/.opencode-config-state" ] || fail 'state foi removido com prova divergente'

  rm -rf "$tmp"
}

uninstall_refuses_canonical_root_divergence_without_mutation() {
  local tmp target fixture_config out status before after

  tmp=$(mktemp -d)
  target="$tmp/opencode"
  fixture_config="$tmp/canonical-copy"
  cp -R "$CONFIG_ROOT" "$fixture_config"
  assert_safe_target_context "$tmp"
  run_cli_with_config_root out status "$fixture_config" install --target "$target"
  assert_exit_zero "$status" 'fixture de canonical_root deve instalar'
  before=$(install_fingerprint "$target")

  run_cli out status uninstall --target "$target"
  assert_exit_nonzero "$status" 'uninstall com canonical_root divergente deve falhar'
  assert_contains "$out" 'canonical_root' 'falha deve mencionar canonical_root'
  after=$(install_fingerprint "$target")
  [ "$before" = "$after" ] || fail 'canonical_root divergente permitiu mutação'
  [ -L "$target/AGENTS.md" ] || fail 'canonical_root divergente removeu link'
  [ -f "$target/.opencode-config-state" ] || fail 'canonical_root divergente removeu state'

  rm -rf "$tmp"
}

uninstall() {
  uninstall_valid_state_preserves_local_and_unknown_content
  uninstall_absent_target_is_noop
  uninstall_refuses_absent_or_corrupt_state_without_mutation
  uninstall_refuses_divergent_literal_and_preserves_everything
  uninstall_refuses_canonical_root_divergence_without_mutation

  printf 'PASS: uninstall\n'
}

all() {
  local os

  os=$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')
  [ "$os" = linux ] || fail "regressão exige Linux; plataforma encontrada: $os"

  inventory
  manifest
  cli
  preflight
  install
  rollback
  uninstall

  printf 'PASS: all\n'
}

case "${1:-}" in
  inventory) inventory ;;
  manifest) manifest ;;
  cli) cli ;;
  preflight) preflight ;;
  install) install ;;
  rollback) rollback ;;
  uninstall) uninstall ;;
  all) all ;;
  install-link-race)
    install_rejects_final_destination_swap_without_escape
    install_rejects_container_swap_without_escape
    install_cleans_link_if_container_moves_after_last_check
    printf 'PASS: install-link-race\n'
    ;;
  install-state-race)
    install_rejects_state_swap_without_external_chmod
    install_rejects_state_publish_swap_without_escape
    install_cleans_state_if_target_moves_before_temp
    install_does_not_overwrite_preexisting_different_state
    printf 'PASS: install-state-race\n'
    ;;
  install-origin-symlink)
    install_rejects_intermediate_source_symlink_escape
    install_rejects_source_swap_after_validation
    printf 'PASS: install-origin-symlink\n'
    ;;
  *) fail 'cenário esperado: inventory, manifest, cli, preflight, install, rollback, uninstall ou all' ;;
esac
