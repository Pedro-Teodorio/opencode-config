#!/usr/bin/env bash
# Biblioteca da CLI opencode-config.
# T5: preflight total, verify estrito e instalação limpa/idempotente.
# T6: backup explícito, replace autorizado e rollback transacional.
# shellcheck shell=bash

# Raiz do repositório: parent de lib/ quando a biblioteca é sourceada.
if [ -z "${OCC_REPO_ROOT:-}" ]; then
  _occ_lib_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
  OCC_REPO_ROOT=$(CDPATH= cd -- "$_occ_lib_dir/.." && pwd -P)
  unset _occ_lib_dir
fi

OCC_CONFIG_ROOT="${OCC_CONFIG_ROOT:-$OCC_REPO_ROOT/config}"
OCC_MANIFEST_ROOT="${OCC_MANIFEST_ROOT:-$OCC_REPO_ROOT/manifest}"
OCC_MANAGED_MANIFEST="${OCC_MANAGED_MANIFEST:-$OCC_MANIFEST_ROOT/managed-files.txt}"
OCC_LOCAL_ONLY_MANIFEST="${OCC_LOCAL_ONLY_MANIFEST:-$OCC_MANIFEST_ROOT/local-only.txt}"

# Detecta o SO efetivo. OPENCODE_CONFIG_FORCE_OS permite simular plataforma nos testes
# sem substituir o binário uname.
opencode_config_detect_os() {
  if [ -n "${OPENCODE_CONFIG_FORCE_OS:-}" ]; then
    printf '%s\n' "$OPENCODE_CONFIG_FORCE_OS"
    return 0
  fi
  uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]'
}

opencode_config_require_linux() {
  local os
  os=$(opencode_config_detect_os)
  case "$os" in
    linux) return 0 ;;
    *)
      printf 'opencode-config: unsupported platform "%s" (Linux required)\n' "$os" >&2
      return 1
      ;;
  esac
}

# Destino padrão: $XDG_CONFIG_HOME/opencode ou $HOME/.config/opencode
opencode_config_default_target() {
  if [ -n "${XDG_CONFIG_HOME:-}" ]; then
    printf '%s/opencode\n' "$XDG_CONFIG_HOME"
  else
    printf '%s/.config/opencode\n' "${HOME:?HOME is required when XDG_CONFIG_HOME is unset}"
  fi
}

opencode_config_usage() {
  cat <<'EOF'
Usage: opencode-config <command> [options]

Commands:
  install    Install managed OpenCode configuration
  verify     Verify managed installation (strict, read-only)
  uninstall  Remove managed links with ownership proof
  help       Show this help

Options:
  --target DIR       Destination directory (default: $XDG_CONFIG_HOME/opencode
                     or $HOME/.config/opencode)
  --replace          Allow replacing conflicting managed targets (requires --backup-dir)
  --backup-dir DIR   Directory for pre-replace backups (requires --replace)
  -h, --help         Show this help

Destructive replacement requires BOTH --replace and --backup-dir.
Linux only. Tests must supply an isolated --target or HOME/XDG.
EOF
}

opencode_config_die() {
  printf 'opencode-config: %s\n' "$1" >&2
  return 1
}

# Parse global/command options. Sets:
#   OCC_COMMAND OCC_TARGET OCC_REPLACE OCC_BACKUP_DIR
opencode_config_parse_args() {
  OCC_COMMAND=
  OCC_TARGET=
  OCC_REPLACE=0
  OCC_BACKUP_DIR=

  if [ "$#" -eq 0 ]; then
    OCC_COMMAND=help
    return 0
  fi

  case "$1" in
    -h|--help|help)
      OCC_COMMAND=help
      return 0
      ;;
    install|verify|uninstall)
      OCC_COMMAND=$1
      shift
      ;;
    *)
      opencode_config_die "unknown command: $1"
      return 1
      ;;
  esac

  while [ "$#" -gt 0 ]; do
    case "$1" in
      -h|--help)
        OCC_COMMAND=help
        return 0
        ;;
      --target)
        if [ "$#" -lt 2 ] || [ -z "${2:-}" ]; then
          opencode_config_die '--target requires a directory argument'
          return 1
        fi
        OCC_TARGET=$2
        shift 2
        ;;
      --backup-dir)
        if [ "$#" -lt 2 ] || [ -z "${2:-}" ]; then
          opencode_config_die '--backup-dir requires a directory argument'
          return 1
        fi
        OCC_BACKUP_DIR=$2
        shift 2
        ;;
      --replace)
        OCC_REPLACE=1
        shift
        ;;
      --)
        shift
        break
        ;;
      -*)
        opencode_config_die "unknown option: $1"
        return 1
        ;;
      *)
        opencode_config_die "unexpected argument: $1"
        return 1
        ;;
    esac
  done

  if [ "$#" -gt 0 ]; then
    opencode_config_die "unexpected argument: $1"
    return 1
  fi

  # Flag combination policy (AC-11): replace and backup-dir are inseparable.
  case "$OCC_COMMAND" in
    install)
      if [ "$OCC_REPLACE" -eq 1 ] && [ -z "$OCC_BACKUP_DIR" ]; then
        opencode_config_die '--replace requires --backup-dir'
        return 1
      fi
      if [ -n "$OCC_BACKUP_DIR" ] && [ "$OCC_REPLACE" -eq 0 ]; then
        opencode_config_die '--backup-dir requires --replace'
        return 1
      fi
      ;;
    verify|uninstall)
      if [ "$OCC_REPLACE" -eq 1 ]; then
        opencode_config_die "$OCC_COMMAND does not accept --replace"
        return 1
      fi
      if [ -n "$OCC_BACKUP_DIR" ]; then
        opencode_config_die "$OCC_COMMAND does not accept --backup-dir"
        return 1
      fi
      ;;
  esac

  if [ -z "$OCC_TARGET" ]; then
    OCC_TARGET=$(opencode_config_default_target)
  fi

  return 0
}

# Valida uma linha de manifesto (path relativo seguro).
opencode_config_validate_manifest_path() {
  local path=$1
  local manifest_name=$2

  if [ -z "$path" ]; then
    opencode_config_die "manifest empty path: $manifest_name"
    return 1
  fi
  case "$path" in
    /*)
      opencode_config_die "manifest absolute path forbidden: $manifest_name: $path"
      return 1
      ;;
    */)
      opencode_config_die "manifest trailing slash forbidden: $manifest_name: $path"
      return 1
      ;;
    *\\*)
      opencode_config_die "manifest backslash forbidden: $manifest_name: $path"
      return 1
      ;;
  esac
  case "/$path/" in
    */./*|*/../*)
      opencode_config_die "manifest unsafe component: $manifest_name: $path"
      return 1
      ;;
  esac
  return 0
}

# Carrega manifesto em array nomeado (nameref). Popula também set associativo opcional.
# Uso: opencode_config_load_manifest FILE ARR_NAME [SET_NAME]
opencode_config_load_manifest() {
  local manifest_path=$1
  local -n _occ_arr=$2
  local set_name=${3:-}
  local path line_no=0

  _occ_arr=()
  if [ -n "$set_name" ]; then
    # shellcheck disable=SC2178
    local -n _occ_set=$set_name
    _occ_set=()
  fi

  if [ ! -f "$manifest_path" ]; then
    opencode_config_die "manifest missing: $manifest_path"
    return 1
  fi
  if [ -L "$manifest_path" ]; then
    opencode_config_die "manifest must not be a symlink: $manifest_path"
    return 1
  fi
  if [ ! -s "$manifest_path" ]; then
    opencode_config_die "manifest empty: $manifest_path"
    return 1
  fi

  while IFS= read -r path || [ -n "$path" ]; do
    line_no=$((line_no + 1))
    opencode_config_validate_manifest_path "$path" "$manifest_path" || return 1
    _occ_arr+=("$path")
    if [ -n "$set_name" ]; then
      _occ_set["$path"]=1
    fi
  done < "$manifest_path"

  return 0
}

# True se rel path é local-only (exato ou sob um entry que é prefixo de diretório).
opencode_config_is_local_only() {
  local rel=$1
  local entry

  for entry in "${OCC_LOCAL_ONLY_LIST[@]+"${OCC_LOCAL_ONLY_LIST[@]}"}"; do
    if [ "$rel" = "$entry" ]; then
      return 0
    fi
    case "$rel" in
      "$entry"/*) return 0 ;;
    esac
  done
  return 1
}

# Resolve path canônico absoluto esperado para um managed path relativo.
opencode_config_expected_canonical() {
  local rel=$1
  local physical
  local root=${OCC_CANONICAL_ROOT:-$OCC_CONFIG_ROOT}

  if [ ! -e "$root/$rel" ] && [ ! -L "$root/$rel" ]; then
    printf '%s\n' "$root/$rel"
    return 0
  fi
  physical=$(readlink -f -- "$root/$rel" 2>/dev/null || true)
  if [ -n "$physical" ]; then
    printf '%s\n' "$physical"
  else
    printf '%s\n' "$root/$rel"
  fi
}

# Classifica um path managed no destino.
# Imprime: ok|missing|conflict_file|conflict_dir|conflict_other|conflict_foreign_link|broken_link
# Para foreign/broken, anexa " -> <raw>" e opcionalmente " (resolved=<abs>)"
opencode_config_classify_managed() {
  local target=$1
  local rel=$2
  local dest expected raw resolved

  dest="$target/$rel"
  expected=$(opencode_config_expected_canonical "$rel")

  if [ -L "$dest" ]; then
    raw=$(readlink -- "$dest" 2>/dev/null || printf '')
    if [ ! -e "$dest" ]; then
      # Link quebrado (alvo ausente) — EC-08
      printf 'broken_link -> %s (expected=%s)\n' "${raw:-?}" "$expected"
      return 0
    fi
    resolved=$(readlink -f -- "$dest" 2>/dev/null || true)
    if [ -n "$resolved" ] && [ "$resolved" = "$expected" ]; then
      printf 'ok\n'
      return 0
    fi
    # Aponta para origem diferente — EC-04
    printf 'conflict_foreign_link -> %s (resolved=%s expected=%s)\n' \
      "${raw:-?}" "${resolved:-unresolved}" "$expected"
    return 0
  fi

  if [ ! -e "$dest" ]; then
    printf 'missing\n'
    return 0
  fi

  if [ -f "$dest" ]; then
    printf 'conflict_file\n'
    return 0
  fi
  if [ -d "$dest" ]; then
    printf 'conflict_dir\n'
    return 0
  fi
  printf 'conflict_other\n'
}

# Carrega manifests e inspeciona o destino.
# Popula arrays globais de relatório:
#   OCC_RPT_MISSING OCC_RPT_OK OCC_RPT_CONFLICT OCC_RPT_FOREIGN
#   OCC_RPT_BROKEN OCC_RPT_UNKNOWN OCC_RPT_REPLACEABLE
# mode: verify | install
opencode_config_inspect_target() {
  local target=$1
  local mode=${2:-verify}
  local rel dest class detail path
  local -a managed_list=()
  local -A managed_set=()

  OCC_RPT_MISSING=()
  OCC_RPT_OK=()
  OCC_RPT_CONFLICT=()
  OCC_RPT_FOREIGN=()
  OCC_RPT_BROKEN=()
  OCC_RPT_UNKNOWN=()
  OCC_RPT_REPLACEABLE=()

  OCC_LOCAL_ONLY_LIST=()
  opencode_config_load_manifest "$OCC_MANAGED_MANIFEST" managed_list managed_set || return 1
  opencode_config_load_manifest "$OCC_LOCAL_ONLY_MANIFEST" OCC_LOCAL_ONLY_LIST || return 1

  if [ -L "$target" ]; then
    opencode_config_die "target must be a real directory, not a symlink: $target"
    return 1
  fi
  if [ -e "$target" ] && [ ! -d "$target" ]; then
    opencode_config_die "target is not a directory: $target"
    return 1
  fi

  # Classifica cada managed path (política estrita: enumera todos).
  for rel in "${managed_list[@]}"; do
    if [ ! -d "$target" ] && [ ! -e "$target" ]; then
      OCC_RPT_MISSING+=("$rel")
      continue
    fi
    detail=$(opencode_config_classify_managed "$target" "$rel")
    class=${detail%% *}
    case "$class" in
      ok)
        OCC_RPT_OK+=("$rel")
        ;;
      missing)
        OCC_RPT_MISSING+=("$rel")
        ;;
      broken_link)
        OCC_RPT_BROKEN+=("$rel|$detail")
        ;;
      conflict_foreign_link)
        OCC_RPT_FOREIGN+=("$rel|$detail")
        ;;
      conflict_file|conflict_dir|conflict_other)
        if [ "$mode" = install ] && [ "${OCC_REPLACE:-0}" -eq 1 ] && [ -n "${OCC_BACKUP_DIR:-}" ]; then
          OCC_RPT_REPLACEABLE+=("$rel|$class")
        else
          OCC_RPT_CONFLICT+=("$rel|$class")
        fi
        ;;
      *)
        OCC_RPT_CONFLICT+=("$rel|$class")
        ;;
    esac
  done

  # Foreign links com --replace também são replaceable no install.
  if [ "$mode" = install ] && [ "${OCC_REPLACE:-0}" -eq 1 ] && [ -n "${OCC_BACKUP_DIR:-}" ]; then
    if [ "${#OCC_RPT_FOREIGN[@]}" -gt 0 ]; then
      for detail in "${OCC_RPT_FOREIGN[@]}"; do
        OCC_RPT_REPLACEABLE+=("$detail")
      done
      OCC_RPT_FOREIGN=()
    fi
    if [ "${#OCC_RPT_BROKEN[@]}" -gt 0 ]; then
      for detail in "${OCC_RPT_BROKEN[@]}"; do
        OCC_RPT_REPLACEABLE+=("$detail")
      done
      OCC_RPT_BROKEN=()
    fi
  fi

  # Scan de unknowns (arquivos e symlinks extras).
  if [ -d "$target" ]; then
    while IFS= read -r -d '' path; do
      rel=${path#"$target"/}
      [ -n "$rel" ] || continue
      if [ -n "${managed_set[$rel]+x}" ]; then
        continue
      fi
      if opencode_config_is_local_only "$rel"; then
        continue
      fi
      OCC_RPT_UNKNOWN+=("$rel")
    done < <(find "$target" \( -type f -o -type l \) -print0 2>/dev/null)
  fi

  return 0
}

# Imprime todas as divergências coletadas (ordem estável por categoria).
opencode_config_print_report() {
  local item rel kind

  for rel in "${OCC_RPT_MISSING[@]+"${OCC_RPT_MISSING[@]}"}"; do
    printf '  missing: %s\n' "$rel"
  done
  for item in "${OCC_RPT_CONFLICT[@]+"${OCC_RPT_CONFLICT[@]}"}"; do
    rel=${item%%|*}
    kind=${item#*|}
    printf '  conflict: %s (%s)\n' "$rel" "$kind"
  done
  for item in "${OCC_RPT_FOREIGN[@]+"${OCC_RPT_FOREIGN[@]}"}"; do
    rel=${item%%|*}
    kind=${item#*|}
    printf '  conflict_foreign_link: %s (%s)\n' "$rel" "$kind"
  done
  for item in "${OCC_RPT_BROKEN[@]+"${OCC_RPT_BROKEN[@]}"}"; do
    rel=${item%%|*}
    kind=${item#*|}
    printf '  broken: %s (%s)\n' "$rel" "$kind"
  done
  for item in "${OCC_RPT_REPLACEABLE[@]+"${OCC_RPT_REPLACEABLE[@]}"}"; do
    rel=${item%%|*}
    kind=${item#*|}
    printf '  replaceable: %s (%s)\n' "$rel" "$kind"
  done
  for rel in "${OCC_RPT_UNKNOWN[@]+"${OCC_RPT_UNKNOWN[@]}"}"; do
    printf '  unknown: %s\n' "$rel"
  done
}

# Conta issues que bloqueiam verify (qualquer divergência exceto ok).
opencode_config_verify_issue_count() {
  local n=0
  n=$((n + ${#OCC_RPT_MISSING[@]}))
  n=$((n + ${#OCC_RPT_CONFLICT[@]}))
  n=$((n + ${#OCC_RPT_FOREIGN[@]}))
  n=$((n + ${#OCC_RPT_BROKEN[@]}))
  n=$((n + ${#OCC_RPT_UNKNOWN[@]}))
  printf '%s\n' "$n"
}

# Conta issues que bloqueiam install (conflitos/foreign/broken/unknown; missing ok).
opencode_config_install_block_count() {
  local n=0
  n=$((n + ${#OCC_RPT_CONFLICT[@]}))
  n=$((n + ${#OCC_RPT_FOREIGN[@]}))
  n=$((n + ${#OCC_RPT_BROKEN[@]}))
  n=$((n + ${#OCC_RPT_UNKNOWN[@]}))
  # replaceable não bloqueia quando --replace está ativo (já movidos para REPLACEABLE)
  printf '%s\n' "$n"
}

# Cria/valida o target sem aceitar um link simbólico como raiz da instalação.
opencode_config_ensure_real_target() {
  if [ -L "$OCC_TARGET" ]; then
    opencode_config_die "target must be a real directory, not a symlink: $OCC_TARGET"
    return 1
  fi
  if [ -e "$OCC_TARGET" ]; then
    if [ ! -d "$OCC_TARGET" ]; then
      opencode_config_die "target is not a directory: $OCC_TARGET"
      return 1
    fi
    return 0
  fi

  if ! mkdir -p -- "$OCC_TARGET"; then
    opencode_config_die "could not create target directory: $OCC_TARGET"
    return 1
  fi
  if [ -L "$OCC_TARGET" ] || [ ! -d "$OCC_TARGET" ]; then
    opencode_config_die "target did not become a real directory: $OCC_TARGET"
    return 1
  fi
}

# Percorre cada componente sob OCC_TARGET. Nunca usa mkdir -p dentro do target,
# para não atravessar silenciosamente um container que virou symlink.
opencode_config_ensure_real_container() {
  local rel=$1 parent component current next
  local -a components=()

  case "$rel" in
    */*) parent=${rel%/*} ;;
    *) return 0 ;;
  esac

  current=$OCC_TARGET
  IFS='/' read -r -a components <<< "$parent"
  for component in "${components[@]}"; do
    next="$current/$component"
    if [ -L "$next" ]; then
      opencode_config_die "managed container is a symlink: $next"
      return 1
    fi
    if [ -e "$next" ]; then
      if [ ! -d "$next" ]; then
        opencode_config_die "managed container is not a directory: $next"
        return 1
      fi
    else
      if ! mkdir -- "$next"; then
        opencode_config_die "could not create managed container: $next"
        return 1
      fi
      if [ -L "$next" ] || [ ! -d "$next" ]; then
        opencode_config_die "managed container did not become a real directory: $next"
        return 1
      fi
    fi
    current=$next
  done
}

opencode_config_validate_state_destination() {
  local state="$OCC_TARGET/.opencode-config-state"

  if [ -L "$state" ]; then
    opencode_config_die "state path must not be a symlink: $state"
    return 1
  fi
  if [ -e "$state" ] && [ ! -f "$state" ]; then
    opencode_config_die "state path must be a regular file: $state"
    return 1
  fi
}

opencode_config_validate_canonical_source() {
  local rel=$1 canonical_root=${OCC_CANONICAL_ROOT:?canonical root must be resolved}
  local output_name=${2:-}
  local component current physical index last_index
  local -a components=()

  current=$canonical_root
  IFS='/' read -r -a components <<< "$rel"
  last_index=$((${#components[@]} - 1))
  for ((index = 0; index <= last_index; index++)); do
    component=${components[$index]}
    current="$current/$component"
    if [ -L "$current" ]; then
      opencode_config_die "canonical source component must not be a symlink: $rel ($component)"
      return 1
    fi
    if [ "$index" -lt "$last_index" ]; then
      if [ ! -d "$current" ]; then
        opencode_config_die "canonical source container is not a directory: $rel ($component)"
        return 1
      fi
    elif [ ! -f "$current" ]; then
      opencode_config_die "canonical managed source must be a regular file: $rel"
      return 1
    fi
  done
  physical=$(readlink -f -- "$current" 2>/dev/null || true)
  case "$physical" in
    "$canonical_root"/*) ;;
    *)
      opencode_config_die "canonical managed source escapes canonical root: $rel"
      return 1
      ;;
  esac
  if [ -n "$output_name" ]; then
    printf -v "$output_name" '%s' "$physical"
  fi
}

opencode_config_validate_canonical_sources() {
  local canonical_root rel
  local -a managed_list=()

  if [ -L "$OCC_CONFIG_ROOT" ] || [ ! -d "$OCC_CONFIG_ROOT" ]; then
    opencode_config_die "canonical root must be a real directory: $OCC_CONFIG_ROOT"
    return 1
  fi
  canonical_root=$(CDPATH= cd -- "$OCC_CONFIG_ROOT" && pwd -P) || {
    opencode_config_die "could not resolve canonical root: $OCC_CONFIG_ROOT"
    return 1
  }
  case "$canonical_root" in
    *$'\n'*|*$'\r'*)
      opencode_config_die "canonical root contains a line-breaking character"
      return 1
      ;;
  esac
  OCC_CANONICAL_ROOT=$canonical_root

  opencode_config_load_manifest "$OCC_MANAGED_MANIFEST" managed_list || return 1
  for rel in "${managed_list[@]}"; do
    opencode_config_validate_canonical_source "$rel" || return 1
  done
}

# Hooks vazios e internos, substituíveis apenas por quem sourceia a biblioteca
# no próprio processo de teste. Não interpretam variáveis nem comandos externos.
opencode_config_test_hook_before_link_publish() { :; }
opencode_config_test_hook_after_link_validation_before_publish() { :; }
opencode_config_test_hook_before_state_publish() { :; }
opencode_config_test_hook_after_state_validation_before_temp() { :; }
opencode_config_test_hook_after_source_validation() { :; }
opencode_config_test_hook_before_item_backup() { :; }
opencode_config_test_hook_after_backup_before_remove() { :; }
opencode_config_test_hook_after_mutation() { :; }

# --- T6: journal, backup e rollback ------------------------------------------

opencode_config_journal_reset() {
  OCC_JOURNAL=()
  OCC_MUTATION_COUNT=0
  OCC_INSTALL_CREATED=0
  OCC_INSTALL_REPLACED=0
  OCC_BACKUP_RUN=
  OCC_CREATED_DIRS=()
  OCC_STATE_ACTION=none
  OCC_STATE_BACKUP=
}

opencode_config_journal_append() {
  OCC_JOURNAL+=("$*")
}

opencode_config_record_mutation() {
  local rel=$1
  OCC_MUTATION_COUNT=$((OCC_MUTATION_COUNT + 1))
  opencode_config_test_hook_after_mutation "$OCC_MUTATION_COUNT" "$rel" || return 1
}

# backup-dir deve ser diretório real (não symlink). Cria subdir exclusivo mode 700.
opencode_config_prepare_backup_run() {
  local parent mode

  if [ -z "${OCC_BACKUP_DIR:-}" ]; then
    opencode_config_die 'internal error: backup-dir required for replace'
    return 1
  fi
  if [ -L "$OCC_BACKUP_DIR" ]; then
    opencode_config_die "backup-dir must be a real directory, not a symlink: $OCC_BACKUP_DIR"
    return 1
  fi
  if [ -e "$OCC_BACKUP_DIR" ] && [ ! -d "$OCC_BACKUP_DIR" ]; then
    opencode_config_die "backup-dir is not a directory: $OCC_BACKUP_DIR"
    return 1
  fi
  if [ ! -d "$OCC_BACKUP_DIR" ]; then
    parent=$(dirname -- "$OCC_BACKUP_DIR")
    if [ -L "$parent" ]; then
      opencode_config_die "backup-dir parent must not be a symlink: $parent"
      return 1
    fi
    if ! mkdir -p -- "$OCC_BACKUP_DIR"; then
      opencode_config_die "could not create backup-dir: $OCC_BACKUP_DIR"
      return 1
    fi
  fi
  if [ -L "$OCC_BACKUP_DIR" ] || [ ! -d "$OCC_BACKUP_DIR" ]; then
    opencode_config_die "backup-dir did not become a real directory: $OCC_BACKUP_DIR"
    return 1
  fi
  if [ ! -w "$OCC_BACKUP_DIR" ]; then
    opencode_config_die "backup-dir is not writable: $OCC_BACKUP_DIR"
    return 1
  fi

  OCC_BACKUP_RUN=$(mktemp -d --tmpdir="$OCC_BACKUP_DIR" 'opencode-config-backup-XXXXXX') || {
    opencode_config_die "could not create exclusive backup run directory under $OCC_BACKUP_DIR"
    return 1
  }
  if ! chmod 700 -- "$OCC_BACKUP_RUN"; then
    rmdir -- "$OCC_BACKUP_RUN" 2>/dev/null || true
    OCC_BACKUP_RUN=
    opencode_config_die 'could not set mode 700 on backup run directory'
    return 1
  fi
  mode=$(stat -c '%a' -- "$OCC_BACKUP_RUN" 2>/dev/null || printf '')
  if [ "$mode" != 700 ]; then
    rm -rf -- "$OCC_BACKUP_RUN"
    OCC_BACKUP_RUN=
    opencode_config_die "backup run directory mode is $mode (expected 700)"
    return 1
  fi
  if [ -L "$OCC_BACKUP_RUN" ]; then
    rm -rf -- "$OCC_BACKUP_RUN"
    OCC_BACKUP_RUN=
    opencode_config_die 'backup run directory must not be a symlink'
    return 1
  fi
}

# Copia o conflito para o backup run preservando path relativo, sem seguir escapes.
opencode_config_backup_item() {
  local rel=$1
  local dest backup_path backup_parent

  dest="$OCC_TARGET/$rel"
  backup_path="$OCC_BACKUP_RUN/$rel"

  opencode_config_test_hook_before_item_backup "$rel" "$dest" "$backup_path" || {
    opencode_config_die "backup hook failed for $rel"
    return 1
  }

  backup_parent=$(dirname -- "$backup_path")
  if [ ! -d "$backup_parent" ]; then
    if ! mkdir -p -- "$backup_parent"; then
      opencode_config_die "could not create backup parent for $rel"
      return 1
    fi
  fi

  # cp -a (= -dR --preserve=all): não dereferencia symlinks no topo nem na árvore.
  if ! cp -a -- "$dest" "$backup_path"; then
    opencode_config_die "could not backup managed path: $rel"
    return 1
  fi

  # Verifica presença e equivalência básica.
  if [ -L "$dest" ]; then
    if [ ! -L "$backup_path" ]; then
      opencode_config_die "backup verification failed (expected symlink): $rel"
      return 1
    fi
    if [ "$(readlink -- "$dest")" != "$(readlink -- "$backup_path")" ]; then
      opencode_config_die "backup symlink text mismatch: $rel"
      return 1
    fi
  elif [ -f "$dest" ]; then
    if [ ! -f "$backup_path" ] || [ -L "$backup_path" ]; then
      opencode_config_die "backup verification failed (expected regular file): $rel"
      return 1
    fi
    if ! cmp -s -- "$dest" "$backup_path"; then
      opencode_config_die "backup content mismatch: $rel"
      return 1
    fi
  elif [ -d "$dest" ]; then
    if [ ! -d "$backup_path" ] || [ -L "$backup_path" ]; then
      opencode_config_die "backup verification failed (expected directory): $rel"
      return 1
    fi
  else
    opencode_config_die "backup verification failed (unsupported type): $rel"
    return 1
  fi

  opencode_config_journal_append "backup|$rel|$backup_path"
  opencode_config_test_hook_after_backup_before_remove "$rel" "$dest" "$backup_path" || {
    opencode_config_die "post-backup hook failed for $rel"
    return 1
  }
}

# Remove o path de conflito no destino sem seguir o componente final como link externo.
opencode_config_remove_conflict_path() {
  local rel=$1
  local dest="$OCC_TARGET/$rel"
  local kind

  if [ -L "$dest" ]; then
    kind=link
    if ! rm -f -- "$dest"; then
      opencode_config_die "could not remove conflicting symlink: $rel"
      return 1
    fi
  elif [ -f "$dest" ]; then
    kind=file
    if ! rm -f -- "$dest"; then
      opencode_config_die "could not remove conflicting file: $rel"
      return 1
    fi
  elif [ -d "$dest" ]; then
    kind=dir
    # Somente diretório real (não symlink — já coberto por -L acima).
    if ! rm -rf -- "$dest"; then
      opencode_config_die "could not remove conflicting directory: $rel"
      return 1
    fi
  else
    opencode_config_die "conflict path disappeared before removal: $rel"
    return 1
  fi

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    opencode_config_die "conflict path still present after removal: $rel"
    return 1
  fi
  opencode_config_journal_append "removed|$rel|$kind"
}

# Garante containers reais e registra apenas diretórios criados nesta execução.
opencode_config_ensure_real_container_journaled() {
  local rel=$1 parent component current next
  local -a components=()

  case "$rel" in
    */*) parent=${rel%/*} ;;
    *) return 0 ;;
  esac

  current=$OCC_TARGET
  IFS='/' read -r -a components <<< "$parent"
  for component in "${components[@]}"; do
    next="$current/$component"
    if [ -L "$next" ]; then
      opencode_config_die "managed container is a symlink: $next"
      return 1
    fi
    if [ -e "$next" ]; then
      if [ ! -d "$next" ]; then
        opencode_config_die "managed container is not a directory: $next"
        return 1
      fi
    else
      if ! mkdir -- "$next"; then
        opencode_config_die "could not create managed container: $next"
        return 1
      fi
      if [ -L "$next" ] || [ ! -d "$next" ]; then
        opencode_config_die "managed container did not become a real directory: $next"
        return 1
      fi
      # Path relativo ao target para rollback de dirs vazios.
      local created_rel=${next#"$OCC_TARGET"/}
      OCC_CREATED_DIRS+=("$created_rel")
      opencode_config_journal_append "created_dir|$created_rel"
    fi
    current=$next
  done
}

opencode_config_publish_link_journaled() {
  local rel=$1 expected=$2
  opencode_config_publish_link_exact "$rel" "$expected" || return 1
  opencode_config_journal_append "created_link|$rel"
  opencode_config_record_mutation "$rel" || return 1
}

# Classes que o preflight marcou como replaceable sob --replace.
opencode_config_class_is_replaceable() {
  case "$1" in
    conflict_file|conflict_dir|conflict_other|conflict_foreign_link|broken_link) return 0 ;;
    *) return 1 ;;
  esac
}

opencode_config_apply_managed_paths() {
  local rel expected detail class
  local -a managed_list=()
  local allow_replace=0

  if [ "${OCC_REPLACE:-0}" -eq 1 ] && [ -n "${OCC_BACKUP_DIR:-}" ]; then
    allow_replace=1
  fi

  opencode_config_load_manifest "$OCC_MANAGED_MANIFEST" managed_list || return 1
  for rel in "${managed_list[@]}"; do
    opencode_config_ensure_real_target || return 1
    expected=
    opencode_config_validate_canonical_source "$rel" expected || return 1
    opencode_config_ensure_real_container_journaled "$rel" || return 1
    detail=$(opencode_config_classify_managed "$OCC_TARGET" "$rel")
    class=${detail%% *}
    case "$class" in
      ok)
        continue
        ;;
      missing)
        opencode_config_publish_link_journaled "$rel" "$expected" || return 1
        OCC_INSTALL_CREATED=$((OCC_INSTALL_CREATED + 1))
        ;;
      *)
        if [ "$allow_replace" -eq 1 ] && opencode_config_class_is_replaceable "$class"; then
          # Revalidação imediata: ainda é o tipo de conflito esperado.
          opencode_config_backup_item "$rel" || return 1
          opencode_config_remove_conflict_path "$rel" || return 1
          opencode_config_publish_link_journaled "$rel" "$expected" || return 1
          OCC_INSTALL_REPLACED=$((OCC_INSTALL_REPLACED + 1))
        else
          opencode_config_die "managed destination changed after preflight: $rel ($detail)"
          return 1
        fi
        ;;
    esac
  done
}

# True se o journal desta run registrou remoção do path relativo.
opencode_config_journal_had_removed() {
  local rel=$1 entry
  for entry in "${OCC_JOURNAL[@]+"${OCC_JOURNAL[@]}"}"; do
    case "$entry" in
      "removed|$rel|"*) return 0 ;;
    esac
  done
  return 1
}

# True se o journal desta run registrou created_link para o path relativo.
opencode_config_journal_had_created_link() {
  local rel=$1 entry
  for entry in "${OCC_JOURNAL[@]+"${OCC_JOURNAL[@]}"}"; do
    case "$entry" in
      "created_link|$rel") return 0 ;;
    esac
  done
  return 1
}

# Remove somente resíduo desta run no dest (symlink/file; dir só se removed journaled).
# Nunca apaga conteúdo que possa ainda ser o original sem backup verificado.
opencode_config_rollback_remove_this_run_residue() {
  local dest=$1
  local allow_dir=${2:-0}

  if [ -L "$dest" ]; then
    rm -f -- "$dest" || return 1
    return 0
  fi
  if [ -f "$dest" ]; then
    rm -f -- "$dest" || return 1
    return 0
  fi
  if [ "$allow_dir" -eq 1 ] && [ -d "$dest" ] && [ ! -L "$dest" ]; then
    rm -rf -- "$dest" || return 1
    return 0
  fi
  # Diretório sem prova de removed desta run: não tocar.
  return 1
}

# Restaura backup para dest; falha de forma audível (sem || true).
opencode_config_rollback_restore_from_backup() {
  local backup_path=$1
  local dest=$2
  local parent

  parent=$(dirname -- "$dest")
  if [ ! -d "$parent" ]; then
    mkdir -p -- "$parent" || {
      printf 'opencode-config: rollback: could not create parent for restore: %s\n' "$dest" >&2
      return 1
    }
  fi
  if ! cp -a -- "$backup_path" "$dest"; then
    printf 'opencode-config: rollback: restore from backup failed: %s -> %s\n' \
      "$backup_path" "$dest" >&2
    return 1
  fi
  return 0
}

# Reverte somente mutações desta execução (ordem inversa do journal).
# AC-09/EC-09: nunca destrói conteúdo original sem restore garantido.
# Retorna non-zero se algum restore crítico falhou (fail loud).
opencode_config_rollback() {
  local entry op rel rest dest backup_path
  local i
  local rc=0
  local had_removed had_created_link backup_ok

  # Journal em ordem LIFO.
  for ((i = ${#OCC_JOURNAL[@]} - 1; i >= 0; i--)); do
    entry=${OCC_JOURNAL[$i]}
    op=${entry%%|*}
    rest=${entry#*|}
    case "$op" in
      created_link)
        rel=$rest
        dest="$OCC_TARGET/$rel"
        # Resíduo desta run: apenas o symlink que publicamos.
        if [ -L "$dest" ]; then
          rm -f -- "$dest" || {
            printf 'opencode-config: rollback: could not remove this-run link: %s\n' "$rel" >&2
            rc=1
          }
        fi
        ;;
      removed)
        # Restauração do conteúdo ocorre no entry backup correspondente.
        :
        ;;
      backup)
        rel=${rest%%|*}
        backup_path=${rest#*|}
        dest="$OCC_TARGET/$rel"
        had_removed=0
        had_created_link=0
        backup_ok=0
        if opencode_config_journal_had_removed "$rel"; then
          had_removed=1
        fi
        if opencode_config_journal_had_created_link "$rel"; then
          had_created_link=1
        fi
        if [ -e "$backup_path" ] || [ -L "$backup_path" ]; then
          backup_ok=1
        fi

        if [ "$backup_ok" -eq 1 ]; then
          if [ -e "$dest" ] || [ -L "$dest" ]; then
            if [ "$had_removed" -eq 1 ]; then
              # Dest é resíduo pós-remove (ex.: created_link); seguro limpar p/ restore.
              if ! opencode_config_rollback_remove_this_run_residue "$dest" 1; then
                printf 'opencode-config: rollback: could not clear this-run residue before restore: %s\n' \
                  "$rel" >&2
                rc=1
                continue
              fi
            elif [ "$had_created_link" -eq 1 ] && [ -L "$dest" ]; then
              if ! rm -f -- "$dest"; then
                printf 'opencode-config: rollback: could not remove this-run link before restore: %s\n' \
                  "$rel" >&2
                rc=1
                continue
              fi
            else
              # Original ainda no dest (remove nunca ocorreu): não sobrescrever.
              continue
            fi
          fi
          if [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
            if ! opencode_config_rollback_restore_from_backup "$backup_path" "$dest"; then
              rc=1
            fi
          fi
        else
          # Backup ausente/ilegível: nunca apagar o que ainda possa ser o original.
          if [ -e "$dest" ] || [ -L "$dest" ]; then
            if [ "$had_removed" -eq 0 ]; then
              # Original intacto no dest — preservar; restore impossível → fail loud.
              printf 'opencode-config: rollback: backup missing; left original in place: %s\n' \
                "$rel" >&2
              rc=1
            elif [ -L "$dest" ] && [ "$had_created_link" -eq 1 ]; then
              # Somente o symlink desta run; remove resíduo e reporta falha.
              rm -f -- "$dest" || true
              printf 'opencode-config: rollback: backup missing after replace; cannot restore: %s\n' \
                "$rel" >&2
              rc=1
            else
              # Original já removido e dest tem algo inesperado — não rm -rf às cegas.
              printf 'opencode-config: rollback: backup missing; refusing unsafe delete: %s\n' \
                "$rel" >&2
              rc=1
            fi
          else
            printf 'opencode-config: rollback: backup missing and destination empty: %s\n' \
              "$rel" >&2
            rc=1
          fi
        fi
        ;;
      created_dir)
        rel=$rest
        dest="$OCC_TARGET/$rel"
        if [ -d "$dest" ] && [ ! -L "$dest" ]; then
          rmdir -- "$dest" 2>/dev/null || true
        fi
        ;;
      state_created)
        dest="$OCC_TARGET/.opencode-config-state"
        if [ -f "$dest" ] && [ ! -L "$dest" ]; then
          rm -f -- "$dest" || {
            printf 'opencode-config: rollback: could not remove this-run state: %s\n' "$dest" >&2
            rc=1
          }
        fi
        ;;
      state_replaced)
        backup_path=$rest
        dest="$OCC_TARGET/.opencode-config-state"
        if [ -f "$backup_path" ] && [ ! -L "$backup_path" ]; then
          # Só remove o state atual se formos restaurar o backup com sucesso.
          if [ -e "$dest" ] || [ -L "$dest" ]; then
            # Se o conteúdo atual ainda é o pré-replace (backup == dest), preserve.
            if [ -f "$dest" ] && [ ! -L "$dest" ] && cmp -s -- "$backup_path" "$dest"; then
              continue
            fi
            if [ -L "$dest" ]; then
              rm -f -- "$dest" || {
                printf 'opencode-config: rollback: could not clear state residue: %s\n' "$dest" >&2
                rc=1
                continue
              }
            elif [ -f "$dest" ]; then
              rm -f -- "$dest" || {
                printf 'opencode-config: rollback: could not clear state before restore: %s\n' "$dest" >&2
                rc=1
                continue
              }
            else
              printf 'opencode-config: rollback: refusing unsafe state delete: %s\n' "$dest" >&2
              rc=1
              continue
            fi
          fi
          if ! cp -a -- "$backup_path" "$dest"; then
            printf 'opencode-config: rollback: state restore failed: %s -> %s\n' \
              "$backup_path" "$dest" >&2
            rc=1
          fi
        else
          # Backup ausente: se o state ainda está presente, não apagar (pode ser o original).
          if [ -f "$dest" ] && [ ! -L "$dest" ]; then
            printf 'opencode-config: rollback: state backup missing; left state in place: %s\n' \
              "$dest" >&2
            rc=1
          elif [ -L "$dest" ]; then
            # Symlink no path de state é sempre inválido/resíduo — remove só o link.
            rm -f -- "$dest" || true
            printf 'opencode-config: rollback: state backup missing; removed invalid state symlink: %s\n' \
              "$dest" >&2
            rc=1
          else
            printf 'opencode-config: rollback: state backup missing and state absent: %s\n' \
              "$dest" >&2
            rc=1
          fi
        fi
        ;;
    esac
  done

  return "$rc"
}

# Limpa run dir de backup somente quando nunca houve material de backup nem
# mutações de replace/state. Qualquer backup|* preserva o run para forense.
opencode_config_cleanup_unused_backup_run() {
  if [ -n "${OCC_BACKUP_RUN:-}" ] && [ -d "$OCC_BACKUP_RUN" ]; then
    local keep=0 entry
    for entry in "${OCC_JOURNAL[@]+"${OCC_JOURNAL[@]}"}"; do
      case "$entry" in
        backup\|*|removed\|*|created_link\|*|state_created\|*|state_replaced\|*)
          keep=1
          break
          ;;
      esac
    done
    if [ "$keep" -eq 0 ]; then
      rm -rf -- "$OCC_BACKUP_RUN" 2>/dev/null || true
      OCC_BACKUP_RUN=
    fi
  fi
}

# Publica um symlink por syscall no diretório já aberto. ln -sT trata o último
# componente como nome exato, nunca como diretório a dereferenciar.
opencode_config_publish_link_exact() {
  local rel=$1 expected=$2
  local parent_rel lexical_parent basename fd fd_path opened current target_physical publish_dest
  local post_opened post_current post_target published_raw source_revalidated

  case "$rel" in
    */*)
      parent_rel=${rel%/*}
      basename=${rel##*/}
      lexical_parent="$OCC_TARGET/$parent_rel"
      ;;
    *)
      basename=$rel
      lexical_parent=$OCC_TARGET
      ;;
  esac

  exec {fd}< "$lexical_parent" || {
    opencode_config_die "could not open managed container for exact publication: $rel"
    return 1
  }
  fd_path="/proc/self/fd/$fd"
  opened=$(readlink -f -- "$fd_path" 2>/dev/null || true)
  target_physical=$(CDPATH= cd -- "$OCC_TARGET" && pwd -P) || {
    exec {fd}<&-
    opencode_config_die "could not resolve target during publication: $rel"
    return 1
  }
  case "$opened" in
    "$target_physical"|"$target_physical"/*) ;;
    *)
      exec {fd}<&-
      opencode_config_die "opened managed container escaped target: $rel"
      return 1
      ;;
  esac

  opencode_config_test_hook_before_link_publish "$rel" "$OCC_TARGET/$rel"

  current=$(readlink -f -- "$lexical_parent" 2>/dev/null || true)
  if [ -z "$current" ] || [ "$current" != "$opened" ] || [ -L "$lexical_parent" ]; then
    exec {fd}<&-
    opencode_config_die "managed container changed before exact publication: $rel"
    return 1
  fi
  opencode_config_test_hook_after_source_validation "$rel" "$expected"
  source_revalidated=
  opencode_config_validate_canonical_source "$rel" source_revalidated || {
    exec {fd}<&-
    return 1
  }
  if [ "$source_revalidated" != "$expected" ]; then
    exec {fd}<&-
    opencode_config_die "canonical source changed immediately before publication: $rel"
    return 1
  fi

  publish_dest="$fd_path/$basename"
  opencode_config_test_hook_after_link_validation_before_publish "$rel" "$publish_dest"
  if ! ln -sT -- "$expected" "$publish_dest"; then
    exec {fd}<&-
    opencode_config_die "could not atomically create exact managed link: $rel"
    return 1
  fi

  # Modelo prático para Bash/Linux: um ator do mesmo uid ainda pode mover o
  # inode aberto, então detectamos logo após a syscall e desfazemos pelo mesmo
  # dirfd somente o symlink exato recém-publicado.
  post_opened=$(readlink -f -- "$fd_path" 2>/dev/null || true)
  post_current=$(readlink -f -- "$lexical_parent" 2>/dev/null || true)
  post_target=$(CDPATH= cd -- "$OCC_TARGET" && pwd -P 2>/dev/null || true)
  if [ -z "$post_opened" ] || [ -z "$post_current" ] || [ -z "$post_target" ] ||
      [ "$post_opened" != "$post_current" ] || [ -L "$lexical_parent" ]; then
    published_raw=$(readlink -- "$publish_dest" 2>/dev/null || true)
    if [ -L "$publish_dest" ] && [ "$published_raw" = "$expected" ]; then
      rm -f -- "$publish_dest"
    fi
    exec {fd}<&-
    opencode_config_die "managed container moved during exact publication: $rel"
    return 1
  fi
  case "$post_opened" in
    "$post_target"|"$post_target"/*) ;;
    *)
      published_raw=$(readlink -- "$publish_dest" 2>/dev/null || true)
      if [ -L "$publish_dest" ] && [ "$published_raw" = "$expected" ]; then
        rm -f -- "$publish_dest"
      fi
      exec {fd}<&-
      opencode_config_die "managed container left target during exact publication: $rel"
      return 1
      ;;
  esac
  source_revalidated=
  if ! opencode_config_validate_canonical_source "$rel" source_revalidated ||
      [ "$source_revalidated" != "$expected" ]; then
    published_raw=$(readlink -- "$publish_dest" 2>/dev/null || true)
    if [ -L "$publish_dest" ] && [ "$published_raw" = "$expected" ]; then
      rm -f -- "$publish_dest"
    fi
    exec {fd}<&-
    opencode_config_die "canonical source changed during publication; managed link removed: $rel"
    return 1
  fi
  exec {fd}<&-
}

# Aplica somente links ausentes (caminho limpo T5). Preferir
# opencode_config_apply_managed_paths quando replace/journal estiverem ativos.
opencode_config_apply_clean_links() {
  opencode_config_apply_managed_paths
}

# Estado v1, determinístico e line-oriented:
#   format=1
#   canonical_root=/path/físico/absoluto/config
#   link=<path relativo> (uma linha por entry do manifesto, em ordem)
opencode_config_build_state_content() {
  local canonical_root=${OCC_CANONICAL_ROOT:?canonical root must be resolved}
  local rel
  local -a managed_list=()

  opencode_config_load_manifest "$OCC_MANAGED_MANIFEST" managed_list || return 1
  printf 'format=1\ncanonical_root=%s\n' "$canonical_root"
  for rel in "${managed_list[@]}"; do
    printf 'link=%s\n' "$rel"
  done
}

opencode_config_target_dirfd_is_current() {
  local fd_path=$1 opened current
  opened=$(readlink -f -- "$fd_path" 2>/dev/null || true)
  current=$(CDPATH= cd -- "$OCC_TARGET" && pwd -P 2>/dev/null || true)
  [ -n "$opened" ] && [ "$opened" = "$current" ] && [ ! -L "$OCC_TARGET" ]
}

# Sem --replace: nunca adota state divergente (T5).
# Com --replace + --backup-dir: permite substituir state após links, com backup.
opencode_config_prepare_state() {
  local fd fd_path state mode
  local allow_replace=0

  if [ "${OCC_REPLACE:-0}" -eq 1 ] && [ -n "${OCC_BACKUP_DIR:-}" ]; then
    allow_replace=1
  fi

  OCC_STATE_CONTENT=$(opencode_config_build_state_content) || return 1
  OCC_STATE_PRESENT=0
  OCC_STATE_ACTION=none
  OCC_STATE_BACKUP=
  exec {fd}< "$OCC_TARGET" || {
    opencode_config_die "could not open target for state validation"
    return 1
  }
  fd_path="/proc/self/fd/$fd"
  if ! opencode_config_target_dirfd_is_current "$fd_path"; then
    exec {fd}<&-
    opencode_config_die "target changed during state validation"
    return 1
  fi
  state="$fd_path/.opencode-config-state"
  if [ ! -e "$state" ] && [ ! -L "$state" ]; then
    OCC_STATE_ACTION=create
    exec {fd}<&-
    return 0
  fi
  if [ -L "$state" ] || [ ! -f "$state" ]; then
    exec {fd}<&-
    opencode_config_die "state path must be a regular non-symlink file"
    return 1
  fi
  mode=$(stat -c '%a' -- "$state" 2>/dev/null || printf '')
  if [ "$mode" = 600 ] && printf '%s\n' "$OCC_STATE_CONTENT" | cmp -s - "$state"; then
    OCC_STATE_PRESENT=1
    OCC_STATE_ACTION=none
    exec {fd}<&-
    return 0
  fi
  if [ "$allow_replace" -eq 1 ]; then
    OCC_STATE_PRESENT=1
    OCC_STATE_ACTION=replace
    exec {fd}<&-
    return 0
  fi
  exec {fd}<&-
  opencode_config_die "preexisting state differs from the expected T5 state; refusing to overwrite"
  return 1
}

opencode_config_write_state() {
  local fd fd_path state temp temp_mode state_inode temp_inode lexical_state

  OCC_STATE_CHANGED=0
  exec {fd}< "$OCC_TARGET" || {
    opencode_config_die "could not open target for state publication"
    return 1
  }
  fd_path="/proc/self/fd/$fd"
  state="$fd_path/.opencode-config-state"
  lexical_state="$OCC_TARGET/.opencode-config-state"
  if ! opencode_config_target_dirfd_is_current "$fd_path"; then
    exec {fd}<&-
    opencode_config_die "target changed before state publication"
    return 1
  fi

  if [ "${OCC_STATE_ACTION:-none}" = none ] && [ "${OCC_STATE_PRESENT:-0}" -eq 1 ]; then
    if [ -L "$state" ] || [ ! -f "$state" ] ||
        ! printf '%s\n' "$OCC_STATE_CONTENT" | cmp -s - "$state" ||
        [ "$(stat -c '%a' -- "$state" 2>/dev/null || printf '')" != 600 ]; then
      exec {fd}<&-
      opencode_config_die "preexisting state changed during install"
      return 1
    fi
    exec {fd}<&-
    return 0
  fi

  if [ "${OCC_STATE_ACTION:-none}" = replace ]; then
    if [ -L "$state" ] || [ ! -f "$state" ]; then
      exec {fd}<&-
      opencode_config_die "state path unsafe during replace publication"
      return 1
    fi
    if [ -z "${OCC_BACKUP_RUN:-}" ]; then
      exec {fd}<&-
      opencode_config_die 'internal error: state replace requires backup run dir'
      return 1
    fi
    OCC_STATE_BACKUP="$OCC_BACKUP_RUN/.opencode-config-state"
    if ! cp -a -- "$state" "$OCC_STATE_BACKUP"; then
      exec {fd}<&-
      opencode_config_die 'could not backup preexisting state before replace'
      return 1
    fi
    opencode_config_journal_append "state_replaced|$OCC_STATE_BACKUP"

    opencode_config_test_hook_after_state_validation_before_temp "$state"
    temp=$(mktemp "$fd_path/.opencode-config-state.tmp.XXXXXX") || {
      exec {fd}<&-
      opencode_config_die "could not create temporary state through target dirfd"
      return 1
    }
    temp_mode=$(stat -c '%a' -- "$temp" 2>/dev/null || printf '')
    if [ "$temp_mode" != 600 ] || ! printf '%s\n' "$OCC_STATE_CONTENT" > "$temp"; then
      rm -f -- "$temp"
      exec {fd}<&-
      opencode_config_die "temporary state is not securely permissioned or writable"
      return 1
    fi
    opencode_config_test_hook_before_state_publish "$state" "$temp"
    if ! opencode_config_target_dirfd_is_current "$fd_path"; then
      rm -f -- "$temp"
      exec {fd}<&-
      opencode_config_die "target changed before state replace"
      return 1
    fi
    # mv -T substitui atomicamente o arquivo regular no mesmo diretório.
    if ! mv -fT -- "$temp" "$state"; then
      rm -f -- "$temp"
      exec {fd}<&-
      opencode_config_die "could not atomically replace state"
      return 1
    fi
    if ! opencode_config_target_dirfd_is_current "$fd_path"; then
      exec {fd}<&-
      opencode_config_die "target moved during state replace"
      return 1
    fi
    OCC_STATE_CHANGED=1
    exec {fd}<&-
    return 0
  fi

  # create (no-clobber)
  if [ -e "$state" ] || [ -L "$state" ]; then
    exec {fd}<&-
    opencode_config_die "state appeared before no-clobber publication"
    return 1
  fi

  opencode_config_test_hook_after_state_validation_before_temp "$state"
  temp=$(mktemp "$fd_path/.opencode-config-state.tmp.XXXXXX") || {
    exec {fd}<&-
    opencode_config_die "could not create temporary state through target dirfd"
    return 1
  }
  if ! opencode_config_target_dirfd_is_current "$fd_path"; then
    rm -f -- "$temp"
    exec {fd}<&-
    opencode_config_die "target moved while creating temporary state"
    return 1
  fi
  temp_mode=$(stat -c '%a' -- "$temp" 2>/dev/null || printf '')
  if [ "$temp_mode" != 600 ] || ! printf '%s\n' "$OCC_STATE_CONTENT" > "$temp"; then
    rm -f -- "$temp"
    exec {fd}<&-
    opencode_config_die "temporary state is not securely permissioned or writable"
    return 1
  fi

  opencode_config_test_hook_before_state_publish "$state" "$temp"
  if ! opencode_config_target_dirfd_is_current "$fd_path" || [ -e "$state" ] || [ -L "$state" ]; then
    rm -f -- "$temp"
    exec {fd}<&-
    opencode_config_die "target/state changed before no-clobber publication"
    return 1
  fi

  # Hard-link no mesmo dirfd é a publicação atômica no-clobber: link(2) falha
  # com EEXIST e nunca substitui um state surgido no intervalo.
  if ! ln -T -- "$temp" "$state"; then
    rm -f -- "$temp"
    exec {fd}<&-
    opencode_config_die "could not atomically publish state without clobber"
    return 1
  fi
  if ! opencode_config_target_dirfd_is_current "$fd_path"; then
    state_inode=$(stat -c '%d:%i' -- "$state" 2>/dev/null || true)
    temp_inode=$(stat -c '%d:%i' -- "$temp" 2>/dev/null || true)
    if [ -n "$state_inode" ] && [ "$state_inode" = "$temp_inode" ]; then
      rm -f -- "$state"
    fi
    rm -f -- "$temp"
    exec {fd}<&-
    opencode_config_die "target moved during state publication; published state removed"
    return 1
  fi
  rm -f -- "$temp"
  OCC_STATE_CHANGED=1
  opencode_config_journal_append "state_created|$lexical_state"
  exec {fd}<&-
}

opencode_config_cmd_install() {
  local blocks need_backup=0 rc=0

  opencode_config_journal_reset

  opencode_config_inspect_target "$OCC_TARGET" install || return 1

  blocks=$(opencode_config_install_block_count)
  if [ "$blocks" -gt 0 ]; then
    printf 'opencode-config: install: preflight failed; aborting (target=%s)\n' "$OCC_TARGET"
    opencode_config_print_report
    return 1
  fi

  if [ "${#OCC_RPT_REPLACEABLE[@]}" -gt 0 ]; then
    need_backup=1
  fi

  # Falhas de origem devem ocorrer antes da primeira mutação no target.
  opencode_config_validate_canonical_sources || return 1

  if [ "$need_backup" -eq 1 ] || { [ "${OCC_REPLACE:-0}" -eq 1 ] && [ -n "${OCC_BACKUP_DIR:-}" ]; }; then
    # prepare_backup_run só é obrigatório quando há replaceables; state replace
    # também precisa do run dir se o state divergir.
    if [ "$need_backup" -eq 1 ]; then
      opencode_config_prepare_backup_run || return 1
    fi
  fi

  # O estado é local-only para inspeção, mas seu path precisa ser seguro antes
  # de qualquer link ser criado.
  if [ -d "$OCC_TARGET" ]; then
    opencode_config_validate_state_destination || return 1
  fi
  opencode_config_ensure_real_target || {
    opencode_config_cleanup_unused_backup_run
    return 1
  }

  # Se state replace for necessário e ainda não há backup run, cria agora.
  opencode_config_prepare_state || {
    opencode_config_cleanup_unused_backup_run
    return 1
  }
  if [ "${OCC_STATE_ACTION:-none}" = replace ] && [ -z "${OCC_BACKUP_RUN:-}" ]; then
    opencode_config_prepare_backup_run || return 1
  fi

  # Captura status compatível com set -e: `cmd || rc=$?` não aborta e preserva o código.
  rc=0
  opencode_config_apply_managed_paths || rc=$?
  if [ "$rc" -ne 0 ]; then
    # rollback pode retornar non-zero (restore incompleto); não engolir sob set -e.
    opencode_config_rollback || true
    # Sem mutação de target: remove run parcial. Com mutação/backup: run fica para forense.
    opencode_config_cleanup_unused_backup_run
    printf 'opencode-config: install: failed; rolled back this-run mutations (target=%s)\n' \
      "$OCC_TARGET" >&2
    return "$rc"
  fi

  rc=0
  opencode_config_write_state || rc=$?
  if [ "$rc" -ne 0 ]; then
    opencode_config_rollback || true
    # State falhou após mutações: mantém backup (cleanup só remove se não houve mutação).
    opencode_config_cleanup_unused_backup_run
    printf 'opencode-config: install: state update failed; rolled back this-run mutations (target=%s)\n' \
      "$OCC_TARGET" >&2
    return "$rc"
  fi

  if [ "$OCC_INSTALL_CREATED" -eq 0 ] && [ "${OCC_INSTALL_REPLACED:-0}" -eq 0 ] && [ "$OCC_STATE_CHANGED" -eq 0 ]; then
    printf 'opencode-config: install: already correct; no changes (target=%s, managed=%s)\n' \
      "$OCC_TARGET" "${#OCC_RPT_OK[@]}"
    opencode_config_cleanup_unused_backup_run
  else
    printf 'opencode-config: install: installed (target=%s, links-created=%s, replaced=%s, state-updated=%s)\n' \
      "$OCC_TARGET" "$OCC_INSTALL_CREATED" "${OCC_INSTALL_REPLACED:-0}" "$OCC_STATE_CHANGED"
  fi
  return 0
}

opencode_config_cmd_verify() {
  local issues

  opencode_config_inspect_target "$OCC_TARGET" verify || return 1

  issues=$(opencode_config_verify_issue_count)
  if [ "$issues" -gt 0 ]; then
    printf 'opencode-config: verify: FAILED (target=%s, issues=%s)\n' "$OCC_TARGET" "$issues"
    opencode_config_print_report
    return 1
  fi

  printf 'opencode-config: verify: OK (target=%s, managed=%s)\n' \
    "$OCC_TARGET" "${#OCC_RPT_OK[@]}"
  return 0
}

opencode_config_uninstall_validate_target_parent() {
  local rel=$1 parent component current next
  local -a components=()

  case "$rel" in
    */*) parent=${rel%/*} ;;
    *) return 0 ;;
  esac

  current=$OCC_TARGET
  IFS='/' read -r -a components <<< "$parent"
  for component in "${components[@]}"; do
    next="$current/$component"
    if [ -L "$next" ] || [ ! -d "$next" ]; then
      opencode_config_die "uninstall proof failed: managed container is not a real directory: $parent"
      return 1
    fi
    current=$next
  done
}

opencode_config_uninstall_validate_link() {
  local rel=$1 expected dest raw current_source

  opencode_config_validate_canonical_source "$rel" current_source || {
    opencode_config_die "uninstall proof failed: canonical source is not current: $rel"
    return 1
  }
  expected="$OCC_CANONICAL_ROOT/$rel"
  if [ "$current_source" != "$expected" ]; then
    opencode_config_die "uninstall proof failed: canonical source changed: $rel"
    return 1
  fi

  opencode_config_uninstall_validate_target_parent "$rel" || return 1
  dest="$OCC_TARGET/$rel"
  if [ ! -L "$dest" ]; then
    opencode_config_die "uninstall proof failed: destination is not a symlink: $rel"
    return 1
  fi
  raw=$(readlink -- "$dest" 2>/dev/null || printf '')
  if [ "$raw" != "$expected" ]; then
    opencode_config_die "uninstall proof diverged: destination literal mismatch: $rel"
    return 1
  fi
}

opencode_config_uninstall_validate_state() {
  local state="$OCC_TARGET/.opencode-config-state"
  local line format_seen=0 canonical_seen=0 link_seen=0 rel canonical_root index
  local expected_state actual_mode
  local -a state_links=() managed_list=()

  if [ -L "$state" ]; then
    opencode_config_die "uninstall state must not be a symlink: $state"
    return 1
  fi
  if [ ! -f "$state" ]; then
    opencode_config_die "uninstall state is absent or not a regular file: $state"
    return 1
  fi
  actual_mode=$(stat -c '%a' -- "$state" 2>/dev/null || printf '')
  if [ "$actual_mode" != 600 ]; then
    opencode_config_die "uninstall state must have mode 600: $state"
    return 1
  fi

  # Resolves and validates the source tree before accepting any ownership claim.
  opencode_config_validate_canonical_sources || return 1
  opencode_config_load_manifest "$OCC_MANAGED_MANIFEST" managed_list || return 1

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      format=1)
        if [ "$format_seen" -ne 0 ] || [ "$canonical_seen" -ne 0 ] || [ "$link_seen" -ne 0 ]; then
          opencode_config_die 'uninstall state has format in an invalid position or duplicated'
          return 1
        fi
        format_seen=1
        ;;
      canonical_root=*)
        if [ "$format_seen" -ne 1 ] || [ "$canonical_seen" -ne 0 ] || [ "$link_seen" -ne 0 ]; then
          opencode_config_die 'uninstall state has canonical_root in an invalid position or duplicated'
          return 1
        fi
        canonical_root=${line#canonical_root=}
        case "$canonical_root" in
          /*) ;;
          *)
            opencode_config_die 'uninstall state canonical_root must be absolute'
            return 1
            ;;
        esac
        [ "$canonical_root" = "$OCC_CANONICAL_ROOT" ] || {
          opencode_config_die "uninstall proof diverged: canonical_root=$canonical_root (current=$OCC_CANONICAL_ROOT)"
          return 1
        }
        canonical_seen=1
        ;;
      link=*)
        if [ "$canonical_seen" -ne 1 ]; then
          opencode_config_die 'uninstall state link appears before canonical_root'
          return 1
        fi
        rel=${line#link=}
        opencode_config_validate_manifest_path "$rel" "$state" || return 1
        state_links+=("$rel")
        link_seen=1
        ;;
      *)
        opencode_config_die "uninstall state has invalid line: $line"
        return 1
        ;;
    esac
  done < "$state"

  if [ "$format_seen" -ne 1 ] || [ "$canonical_seen" -ne 1 ] ||
      [ "${#state_links[@]}" -ne "${#managed_list[@]}" ]; then
    opencode_config_die 'uninstall state is incomplete or corrupt'
    return 1
  fi
  for ((index = 0; index < ${#managed_list[@]}; index++)); do
    if [ "${state_links[$index]}" != "${managed_list[$index]}" ]; then
      opencode_config_die "uninstall proof diverged: state link order/path mismatch at index $index"
      return 1
    fi
  done

  expected_state=$(opencode_config_build_state_content) || return 1
  if ! printf '%s\n' "$expected_state" | cmp -s - "$state"; then
    opencode_config_die 'uninstall state content differs from the current manifest'
    return 1
  fi

  OCC_UNINSTALL_LINKS=("${state_links[@]}")
  for rel in "${OCC_UNINSTALL_LINKS[@]}"; do
    opencode_config_uninstall_validate_link "$rel" || return 1
  done
}

opencode_config_uninstall_cleanup_containers() {
  local rel parent path candidate_depth depth max_depth=0
  local -A parents=()
  local -a parent_components=()

  for rel in "${OCC_UNINSTALL_LINKS[@]}"; do
    case "$rel" in
      */*) parent=${rel%/*} ;;
      *) continue ;;
    esac
    while [ -n "$parent" ]; do
      parents["$parent"]=1
      parent_components=()
      IFS='/' read -r -a parent_components <<< "$parent"
      if [ "${#parent_components[@]}" -gt "$max_depth" ]; then
        max_depth=${#parent_components[@]}
      fi
      case "$parent" in
        */*) parent=${parent%/*} ;;
        *) parent= ;;
      esac
    done
  done

  # Somente rmdir: conteúdo local/unknown torna a operação um no-op seguro.
  for ((depth = max_depth; depth >= 1; depth--)); do
    for parent in "${!parents[@]}"; do
      parent_components=()
      IFS='/' read -r -a parent_components <<< "$parent"
      candidate_depth=${#parent_components[@]}
      [ "$candidate_depth" -eq "$depth" ] || continue
      path="$OCC_TARGET/$parent"
      if [ -d "$path" ] && [ ! -L "$path" ]; then
        rmdir -- "$path" 2>/dev/null || true
      fi
    done
  done
}

opencode_config_cmd_uninstall() {
  local rel state removed=0
  local state_content expected_state

  if [ ! -e "$OCC_TARGET" ] && [ ! -L "$OCC_TARGET" ]; then
    printf 'opencode-config: uninstall: already absent (target=%s)\n' "$OCC_TARGET"
    return 0
  fi
  if [ -L "$OCC_TARGET" ] || [ ! -d "$OCC_TARGET" ]; then
    opencode_config_die "uninstall target must be a real directory: $OCC_TARGET"
    return 1
  fi

  # Todo o conjunto é validado antes da primeira remoção.
  opencode_config_uninstall_validate_state || return 1

  for rel in "${OCC_UNINSTALL_LINKS[@]}"; do
    # Revalidação imediata mantém a remoção limitada a symlink + literal provados.
    opencode_config_uninstall_validate_link "$rel" || return 1
    if ! rm -f -- "$OCC_TARGET/$rel"; then
      opencode_config_die "could not remove owned symlink: $rel"
      return 1
    fi
    if [ -e "$OCC_TARGET/$rel" ] || [ -L "$OCC_TARGET/$rel" ]; then
      opencode_config_die "owned symlink remained after removal: $rel"
      return 1
    fi
    removed=$((removed + 1))
  done

  state="$OCC_TARGET/.opencode-config-state"
  state_content=$(<"$state")
  expected_state=$(opencode_config_build_state_content) || return 1
  if [ "$state_content" != "$expected_state" ] ||
      [ "$(stat -c '%a' -- "$state" 2>/dev/null || printf '')" != 600 ]; then
    opencode_config_die 'uninstall state changed before safe removal; preserving state'
    return 1
  fi
  if ! rm -f -- "$state"; then
    opencode_config_die 'could not remove validated uninstall state'
    return 1
  fi
  if [ -e "$state" ] || [ -L "$state" ]; then
    opencode_config_die 'validated uninstall state remained after removal'
    return 1
  fi

  opencode_config_uninstall_cleanup_containers
  printf 'opencode-config: uninstall: uninstalled (target=%s, links-removed=%s)\n' \
    "$OCC_TARGET" "$removed"
  return 0
}

opencode_config_main() {
  # Parse first so help/unknown work even before platform gate when appropriate.
  opencode_config_parse_args "$@" || return $?

  case "$OCC_COMMAND" in
    help)
      opencode_config_usage
      return 0
      ;;
  esac

  opencode_config_require_linux || return $?

  case "$OCC_COMMAND" in
    install) opencode_config_cmd_install ;;
    verify) opencode_config_cmd_verify ;;
    uninstall) opencode_config_cmd_uninstall ;;
    *)
      opencode_config_die "internal error: unhandled command: $OCC_COMMAND"
      return 1
      ;;
  esac
}
