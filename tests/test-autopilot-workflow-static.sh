#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

PROJECT_NAME="autopilot-workflow-static-app"
PROJECT_DIR="$TEST_DIR/$PROJECT_NAME"

fail() {
  echo "$*" >&2
  exit 1
}

require_pattern() {
  local path="$1"
  local expected="$2"

  grep -Eq "$expected" "$path" || \
    fail "Expected pattern '$expected' in $path"
}

reject_pattern() {
  local path="$1"
  local rejected="$2"

  if grep -Eq "$rejected" "$path"; then
    fail "Rejected pattern '$rejected' in $path"
  fi
}

reject_unpinned_remote_uses() {
  local path="$1"
  local use

  while IFS= read -r use; do
    use="${use#\"}"
    use="${use%\"}"
    use="${use#\'}"
    use="${use%\'}"

    case "$use" in
      ./*) ;;
      docker://*)
        [[ "$use" == *@sha256:* ]] || \
          fail "Unpinned remote use '$use' in $path"
        ;;
      *)
        [[ "$use" =~ @[[:xdigit:]]{40}$ ]] || \
          fail "Unpinned remote use '$use' in $path"
        ;;
    esac
  done < <(
    sed -nE \
      's/^[[:space:]]*(-[[:space:]]*)?uses:[[:space:]]*([^[:space:]#]+).*/\2/p' "$path"
  )
}

reject_secrets_in_run_blocks() {
  local path="$1"

  awk '
    function indentation(line, prefix) {
      prefix = line
      sub(/[^[:space:]].*$/, "", prefix)
      return length(prefix)
    }

    function has_secrets_expression(line) {
      return line ~ /\$\{\{[[:space:]]*secrets\./ ||
        line ~ /\$\{\{[[:space:]]*secrets[[:space:]]*\[/
    }

    /^[[:space:]]*(-[[:space:]]*)?run:[[:space:]]*/ {
      run_indent = indentation($0)
      in_run = 1
      if (has_secrets_expression($0)) {
        exit 1
      }
      next
    }

    in_run && /^[[:space:]]*$/ {
      next
    }

    in_run {
      if (indentation($0) <= run_indent) {
        in_run = 0
      }
      if (in_run && has_secrets_expression($0)) {
        exit 1
      }
    }
  ' "$path" || fail "Rejected secrets expression in run block: $path"
}

require_run_command() {
  local path="$1"
  local expected="$2"

  awk -v expected="$expected" '
    function indentation(line, prefix) {
      prefix = line
      sub(/[^[:space:]].*$/, "", prefix)
      return length(prefix)
    }

    function matches_command(line, command) {
      command = line
      sub(/^[[:space:]]+/, "", command)
      sub(/[[:space:]]+$/, "", command)
      return command == expected
    }

    /^[[:space:]]*(-[[:space:]]*)?run:[[:space:]]*/ {
      run_indent = indentation($0)
      in_run = 1
      command = $0
      sub(/^[[:space:]]*(-[[:space:]]*)?run:[[:space:]]*/, "", command)
      if (command !~ /^[>|]/ && matches_command(command)) {
        found = 1
      }
      next
    }

    in_run && /^[[:space:]]*$/ {
      next
    }

    in_run {
      if (indentation($0) <= run_indent) {
        in_run = 0
      }
      if (in_run && matches_command($0)) {
        found = 1
      }
    }

    END { exit found ? 0 : 1 }
  ' "$path" || fail "Expected run command '$expected' in $path"
}

"$ROOT_DIR/bin/new-full-project" --no-git "$PROJECT_NAME" "$TEST_DIR" >/dev/null

ENROLLMENT_WORKFLOW="$PROJECT_DIR/.github/workflows/autopilot-enrollment.yml"
UPGRADE_RECEIVER_WORKFLOW="$PROJECT_DIR/.github/workflows/autopilot-upgrade-receiver.yml"

[[ -f "$ENROLLMENT_WORKFLOW" ]] || \
  fail "Missing required autopilot enrollment workflow: $ENROLLMENT_WORKFLOW"
[[ -f "$UPGRADE_RECEIVER_WORKFLOW" ]] || \
  fail "Missing required autopilot upgrade receiver workflow: $UPGRADE_RECEIVER_WORKFLOW"

for workflow in "$ENROLLMENT_WORKFLOW" "$UPGRADE_RECEIVER_WORKFLOW"; do
  require_pattern "$workflow" '^[[:space:]]*permissions:'
  reject_pattern "$workflow" '^[[:space:]]*permissions:[[:space:]]*write-all([[:space:]]|$)'
  reject_pattern "$workflow" '^[[:space:]]*contents:[[:space:]]*write([[:space:]]|$)'
  reject_pattern "$workflow" '^[[:space:]]*actions:[[:space:]]*write([[:space:]]|$)'
  reject_pattern "$workflow" '^[[:space:]]*checks:[[:space:]]*write([[:space:]]|$)'
  reject_pattern "$workflow" '^[[:space:]]*pull-requests:[[:space:]]*write([[:space:]]|$)'
  reject_pattern "$workflow" '^[[:space:]]*id-token:[[:space:]]*write([[:space:]]|$)'
  reject_pattern "$workflow" '^[[:space:]]*pull_request_target:'
  reject_pattern "$workflow" 'git[[:space:]]+push.*(HEAD:|refs/heads/)?(main|master)([[:space:]]|$)'
  reject_unpinned_remote_uses "$workflow"
  reject_secrets_in_run_blocks "$workflow"
done

require_run_command "$ENROLLMENT_WORKFLOW" "scripts/check-harness.sh"
require_run_command "$ENROLLMENT_WORKFLOW" "scripts/check-lifecycle-gate.sh plan"
require_run_command "$ENROLLMENT_WORKFLOW" \
  "scripts/check-autopilot-contract.sh enrollment"
require_pattern "$ENROLLMENT_WORKFLOW" 'protected-diff.*BASE_SHA.*HEAD_SHA'
require_pattern "$ENROLLMENT_WORKFLOW" 'github[.]event[.]pull_request[.]base[.]sha'
require_pattern "$ENROLLMENT_WORKFLOW" 'github[.]event[.]pull_request[.]head[.]sha'
require_pattern "$ENROLLMENT_WORKFLOW" 'git worktree add --detach'
require_pattern "$ENROLLMENT_WORKFLOW" 'RUNNER_TEMP'
require_pattern "$ENROLLMENT_WORKFLOW" 'trusted-harness-base/scripts/check-autopilot-contract[.]sh'

echo "Autopilot workflow static test passed."
