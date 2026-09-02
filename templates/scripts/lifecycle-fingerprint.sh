#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_FILE="$ROOT_DIR/.ai/LIFECYCLE_STATE"

fail() {
  echo "lifecycle-fingerprint: $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage: scripts/lifecycle-fingerprint.sh <gate>

Gates:
  plan design prototype implementation release github retrospective
USAGE
}

[[ $# -eq 1 ]] || {
  usage >&2
  exit 2
}

GATE="$1"
case "$GATE" in
  plan|design|prototype|implementation|release|github|retrospective) ;;
  *) fail "Unknown lifecycle gate: $GATE" ;;
esac

[[ -f "$STATE_FILE" ]] || fail "Missing lifecycle state: .ai/LIFECYCLE_STATE"

state_value() {
  local key="$1"
  local count

  count="$(awk -F= -v key="$key" '$1 == key { count++ } END { print count + 0 }' "$STATE_FILE")"
  [[ "$count" == 1 ]] || fail "State key must occur exactly once: $key"
  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print }' "$STATE_FILE"
}

digest_stdin() {
  local output
  local crc
  local bytes

  if command -v shasum >/dev/null 2>&1; then
    output="$(shasum -a 256)"
    printf 'sha256:%s\n' "${output%% *}"
  elif command -v sha256sum >/dev/null 2>&1; then
    output="$(sha256sum)"
    printf 'sha256:%s\n' "${output%% *}"
  elif command -v openssl >/dev/null 2>&1; then
    output="$(openssl dgst -sha256)"
    printf 'sha256:%s\n' "${output##* }"
  else
    read -r crc bytes _ < <(cksum)
    printf 'cksum:%s:%s\n' "$crc" "$bytes"
  fi
}

digest_file() {
  digest_stdin < "$1"
}

project_files_nul() {
  local relative

  if command -v git >/dev/null 2>&1 && \
    git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r -d '' relative; do
      printf '%s\0' "$ROOT_DIR/$relative"
    done < <(git -C "$ROOT_DIR" ls-files -z --cached --others --exclude-standard)
  else
    find "$ROOT_DIR" \
      \( -type d \( \
        -name .git -o \
        -name node_modules -o \
        -name .venv -o \
        -name venv -o \
        -name .tox -o \
        -name .pytest_cache -o \
        -name .mypy_cache -o \
        -name .ruff_cache -o \
        -name .cache -o \
        -name .next -o \
        -name coverage -o \
        -name build -o \
        -name target -o \
        -name .gradle \
      \) -prune \) -o \( -type f -o -type l \) -print0
  fi
}

reject_ambiguous_paths() {
  local path

  while IFS= read -r -d '' path; do
    case "$path" in
      *$'\n'*|*$'\r'*) fail "Filenames containing newlines are unsupported: ${path#"$ROOT_DIR/"}" ;;
    esac
  done < <(project_files_nul)
}

sorted_project_files() {
  local path

  while IFS= read -r -d '' path; do
    printf '%s\n' "$path"
  done < <(project_files_nul) | sort
}

emit_file() {
  local relative="$1"
  local path="$ROOT_DIR/$relative"
  local file_digest

  [[ -f "$path" || -L "$path" ]] || return 0
  if [[ -L "$path" ]]; then
    file_digest="$({ printf 'SYMLINK\0'; readlink "$path"; } | digest_stdin)"
  else
    file_digest="$(digest_file "$path")"
  fi
  printf 'PATH_LENGTH=%s\nPATH=%s\nDIGEST=%s\n' \
    "${#relative}" "$relative" "$file_digest"
}

emit_tree() {
  local relative_root="$1"
  local absolute_root="$ROOT_DIR/$relative_root"
  local path
  local relative

  [[ -d "$absolute_root" ]] || return 0
  while IFS= read -r path; do
    relative="${path#"$ROOT_DIR/"}"
    emit_file "$relative"
  done < <(find "$absolute_root" \( -type f -o -type l \) -print | sort)
}

emit_implementation_tree() {
  local path
  local relative

  while IFS= read -r path; do
    relative="${path#"$ROOT_DIR/"}"
    case "$relative" in
      .git/*|.ai/LIFECYCLE_STATE|.ai/LIFECYCLE_BASELINE|.ai/PROJECT_CONTEXT.md|.ai/PROJECT_HISTORY.md|.ai/.lifecycle-record.lock/*|dist/*|docs/lifecycle/RETROSPECTIVE.md|docs/lifecycle/IMPROVEMENT_PROPOSAL.md|.DS_Store|*/.DS_Store|*.tmp.*|*.valid|*.fresh) continue ;;
    esac
    emit_file "$relative"
  done < <(sorted_project_files)
}

emit_scope() {
  case "$GATE" in
    plan)
      printf 'RISK_LEVEL=%s\n' "$(state_value RISK_LEVEL)"
      emit_file "docs/lifecycle/PROBLEM_FRAMING.md"
      ;;
    design)
      emit_tree "docs/product"
      emit_tree "docs/technical"
      emit_tree "docs/data"
      emit_file "docs/lifecycle/DESIGN_CHALLENGE.md"
      ;;
    prototype)
      emit_tree "docs/design"
      emit_tree "docs/design-review"
      emit_file "docs/lifecycle/PROTOTYPE_SMOKE_TEST.md"
      ;;
    implementation)
      emit_implementation_tree
      ;;
    release)
      printf 'HUMAN_APPROVAL_REF=%s\n' "$(state_value HUMAN_APPROVAL_REF)"
      emit_tree "dist"
      ;;
    github)
      printf 'GITHUB_APPROVAL_REF=%s\n' "$(state_value GITHUB_APPROVAL_REF)"
      ;;
    retrospective)
      emit_file "docs/lifecycle/RETROSPECTIVE.md"
      emit_file "docs/lifecycle/IMPROVEMENT_PROPOSAL.md"
      ;;
  esac
}

reject_ambiguous_paths
emit_scope | digest_stdin
