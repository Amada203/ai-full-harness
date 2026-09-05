#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUTOPILOT_DIR="$ROOT_DIR/.autopilot"

fail() {
  echo "autopilot-fingerprint: $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage: scripts/autopilot-fingerprint.sh <target>

Targets:
  constitution  Fingerprint the immutable constitution.
  policy        Fingerprint the owner policy.
  static-contract  Fingerprint static contract files other than owner policy.
  contract      Fingerprint all static Autopilot contract files.
USAGE
}

[[ $# -eq 1 ]] || {
  usage >&2
  exit 2
}

TARGET="$1"
case "$TARGET" in
  constitution)
    FILES=(.autopilot/CONSTITUTION.yml)
    ;;
  policy)
    FILES=(.autopilot/POLICY.yml)
    ;;
  static-contract)
    FILES=(
      .autopilot/CONSTITUTION.yml
      .autopilot/ENROLLMENT.yml
      .autopilot/OBJECTIVES.md
      .autopilot/PROTECTED_PATHS.yml
    )
    ;;
  contract)
    # AUTOPILOT_STATE is mutable bookkeeping, so it is deliberately not part
    # of the contract fingerprint.
    FILES=(
      .autopilot/CONSTITUTION.yml
      .autopilot/ENROLLMENT.yml
      .autopilot/OBJECTIVES.md
      .autopilot/POLICY.yml
      .autopilot/PROTECTED_PATHS.yml
    )
    ;;
  *)
    fail "Unknown target: $TARGET"
    ;;
esac

digest_stdin() {
  local output
  local digest
  local crc
  local bytes

  if command -v shasum >/dev/null 2>&1; then
    output="$(shasum -a 256)" || fail "shasum failed"
    digest="${output%% *}"
    [[ "$output" == "$digest  -" ]] || fail "Malformed shasum output"
    [[ "$digest" =~ ^[[:xdigit:]]{64}$ ]] || fail "Malformed shasum digest"
    printf 'sha256:%s\n' "$digest"
  elif command -v sha256sum >/dev/null 2>&1; then
    output="$(sha256sum)" || fail "sha256sum failed"
    digest="${output%% *}"
    [[ "$output" == "$digest  -" ]] || fail "Malformed sha256sum output"
    [[ "$digest" =~ ^[[:xdigit:]]{64}$ ]] || fail "Malformed sha256sum digest"
    printf 'sha256:%s\n' "$digest"
  elif command -v openssl >/dev/null 2>&1; then
    output="$(openssl dgst -sha256)" || fail "openssl failed"
    digest="${output##* }"
    case "$output" in
      "SHA2-256(stdin)= $digest"|"SHA256(stdin)= $digest") ;;
      *) fail "Malformed openssl output" ;;
    esac
    [[ "$digest" =~ ^[[:xdigit:]]{64}$ ]] || fail "Malformed openssl digest"
    printf 'sha256:%s\n' "$digest"
  else
    output="$(cksum)" || fail "cksum failed"
    case "$output" in
      *$'\n'*|*$'\r'*) fail "Malformed cksum output" ;;
    esac
    [[ "$output" =~ ^[0-9]+[[:blank:]]+[0-9]+$ ]] || \
      fail "Malformed cksum output"
    read -r crc bytes <<< "$output"
    printf 'cksum:%s:%s\n' "$crc" "$bytes"
  fi
}

digest_file() {
  digest_stdin < "$1"
}

validate_flat_control_framing() {
  local relative="$1"
  local path="$ROOT_DIR/$relative"
  local line
  local key

  # This is lexical framing for flat key/value controls, not YAML schema
  # validation. Semantic key and value checks belong to the validator.
  case "$relative" in
    .autopilot/CONSTITUTION.yml|.autopilot/ENROLLMENT.yml|\
    .autopilot/POLICY.yml|.autopilot/PROTECTED_PATHS.yml)
      ;;
    *)
      return 0
      ;;
  esac

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    [[ "$line" == *:* ]] || fail "Malformed data line in $relative"

    key="${line%%:*}"
    [[ "$key" =~ ^[a-z][a-z0-9_]*$ ]] || \
      fail "Malformed key name in $relative: $key"
  done < "$path"
}

reject_ambiguous_paths() {
  local path
  local relative

  [[ -d "$AUTOPILOT_DIR" ]] || fail "Missing Autopilot directory: .autopilot"
  [[ ! -L "$AUTOPILOT_DIR" ]] || fail "Autopilot directory must not be a symlink"
  if ! find "$AUTOPILOT_DIR" -print0 | while IFS= read -r -d '' path; do
    relative="${path#"$ROOT_DIR/"}"
    case "$relative" in
      *$'\n'*|*$'\r'*)
        fail "Filenames containing newlines are unsupported: $relative"
        ;;
    esac
  done; then
    fail "Unable to enumerate Autopilot paths"
  fi
}

validate_file() {
  local relative="$1"
  local path="$ROOT_DIR/$relative"

  [[ -e "$path" || -L "$path" ]] || fail "Missing control file: $relative"
  [[ ! -L "$path" ]] || fail "Control file must not be a symlink: $relative"
  [[ -f "$path" ]] || fail "Control file must be regular: $relative"
  validate_flat_control_framing "$relative"
}

emit_file() {
  local relative="$1"
  local path="$ROOT_DIR/$relative"
  local file_digest

  validate_file "$relative"
  if ! file_digest="$(digest_file "$path")"; then
    fail "Unable to digest control file: $relative"
  fi
  printf 'PATH_LENGTH=%s\nPATH=%s\nDIGEST=%s\n' \
    "${#relative}" "$relative" "$file_digest"
}

reject_ambiguous_paths

manifest=
if ! manifest="$(
  for relative in "${FILES[@]}"; do
    emit_file "$relative"
  done
)"; then
  fail "Unable to build Autopilot fingerprint manifest"
fi
printf '%s\n' "$manifest" | digest_stdin
