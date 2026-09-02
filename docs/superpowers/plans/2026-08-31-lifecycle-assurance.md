# Lifecycle Assurance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add risk-adjusted, evidence-backed lifecycle gates for first-principles reasoning, U-shaped thinking, smoke testing, and adversarial review.

**Architecture:** Keep `.ai/PROJECT_RULES.md` as the behavioral source of truth, add a non-executable `.ai/LIFECYCLE_STATE` control file, place human evidence in `docs/lifecycle/`, and enforce mechanical invariants with a standalone Bash gate validator. Preserve `check-harness.sh` as the structural validator and test generation plus positive and negative gate paths end to end.

**Tech Stack:** Portable Bash, Markdown templates, Git-based project templates

---

No commits are included in these steps because this repository explicitly
requires user approval before committing.

### Task 1: Add failing generator and structure expectations

**Files:**

- Modify: `tests/test-new-full-project.sh`
- Test: `tests/test-new-full-project.sh`

- [x] **Step 1: Add expectations for version 2.1.0 and lifecycle files**

```bash
assert_file "$PROJECT_DIR/.ai/LIFECYCLE_STATE"
assert_file "$PROJECT_DIR/docs/lifecycle/README.md"
assert_file "$PROJECT_DIR/docs/lifecycle/PROBLEM_FRAMING.md"
assert_file "$PROJECT_DIR/docs/lifecycle/DESIGN_CHALLENGE.md"
assert_file "$PROJECT_DIR/docs/lifecycle/PROTOTYPE_SMOKE_TEST.md"
assert_file "$PROJECT_DIR/docs/lifecycle/SMOKE_TEST_REPORT.md"
assert_file "$PROJECT_DIR/docs/lifecycle/ADVERSARIAL_REVIEW.md"
assert_file "$PROJECT_DIR/docs/lifecycle/RETROSPECTIVE.md"
assert_file "$PROJECT_DIR/scripts/check-lifecycle-gate.sh"
assert_contains "$PROJECT_DIR/.ai/HARNESS_VERSION" "2.1.0"
assert_missing "$PROJECT_DIR/.DS_Store"
```

- [x] **Step 2: Run the generator test and verify failure**

Run: `bash tests/test-new-full-project.sh`

Expected: non-zero exit because lifecycle files are absent, or because binary
metadata is incorrectly processed as a text template.

### Task 2: Add lifecycle templates and generator robustness

**Files:**

- Modify: `templates/.ai/HARNESS_VERSION`
- Create: `templates/.ai/LIFECYCLE_STATE`
- Create: `templates/docs/lifecycle/README.md`
- Create: `templates/docs/lifecycle/PROBLEM_FRAMING.md`
- Create: `templates/docs/lifecycle/DESIGN_CHALLENGE.md`
- Create: `templates/docs/lifecycle/PROTOTYPE_SMOKE_TEST.md`
- Create: `templates/docs/lifecycle/SMOKE_TEST_REPORT.md`
- Create: `templates/docs/lifecycle/ADVERSARIAL_REVIEW.md`
- Create: `templates/docs/lifecycle/RETROSPECTIVE.md`
- Modify: `bin/new-full-project`

- [x] **Step 1: Set initial machine state**

```text
SCHEMA_VERSION=1
RISK_LEVEL=M
CURRENT_GATE=plan
PLAN_STATUS=BLOCKED
DESIGN_STATUS=BLOCKED
PROTOTYPE_STATUS=BLOCKED
IMPLEMENTATION_STATUS=BLOCKED
RELEASE_STATUS=BLOCKED
GITHUB_STATUS=BLOCKED
RETROSPECTIVE_STATUS=BLOCKED
HUMAN_APPROVAL_REF=NONE
GITHUB_APPROVAL_REF=NONE
```

- [x] **Step 2: Add focused evidence templates**

Each template contains the headings defined in the design and uses
`<!-- REQUIRED: replace with concrete evidence -->` for incomplete fields.
Smoke templates include `Result: BLOCKED`; adversarial review includes
`Decision: BLOCKED` and a findings table; prototype smoke includes an
`Applicability:` line.

- [x] **Step 3: Prevent binary metadata rendering**

After copying templates, remove generated `.DS_Store` files. In the placeholder
loop, use a text-file check before invoking `sed`:

```bash
find "$PROJECT_DIR" -name '.DS_Store' -type f -delete

while IFS= read -r file; do
  if ! LC_ALL=C grep -Iq . "$file"; then
    continue
  fi
  tmp_file="${file}.tmp.$$"
  sed \
    -e "s/{{PROJECT_NAME}}/${PROJECT_NAME_ESCAPED}/g" \
    -e "s/{{PROJECT_STACK}}/${PROJECT_STACK_ESCAPED}/g" \
    -e "s/{{PROJECT_DESCRIPTION}}/${PROJECT_DESCRIPTION_ESCAPED}/g" \
    -e "s/{{HARNESS_VERSION}}/${HARNESS_VERSION_ESCAPED}/g" \
    -e "s/{{TODAY}}/${TODAY_ESCAPED}/g" \
    "$file" > "$tmp_file"
  mv "$tmp_file" "$file"
done < <(find "$PROJECT_DIR" -type f -print)
```

- [x] **Step 4: Run the generator test**

Run: `bash tests/test-new-full-project.sh`

Expected: it advances beyond lifecycle file assertions and fails because the
gate validator or its integration is not implemented yet.

### Task 3: Specify lifecycle gate behavior with failing tests

**Files:**

- Create: `tests/test-lifecycle-gates.sh`
- Test: `tests/test-lifecycle-gates.sh`

- [x] **Step 1: Add safe fixture-editing helpers**

```bash
replace_literal() {
  local path="$1" old="$2" new="$3" tmp_path="${1}.tmp.$$"
  awk -v old="$old" -v new="$new" '{ gsub(old, new); print }' \
    "$path" > "$tmp_path"
  mv "$tmp_path" "$path"
}

expect_fail() {
  local expected="$1"
  shift
  if output="$("$@" 2>&1)"; then
    echo "Expected command to fail: $*" >&2
    exit 1
  fi
  case "$output" in
    *"$expected"*) ;;
    *) echo "Missing failure text '$expected': $output" >&2; exit 1 ;;
  esac
}
```

- [x] **Step 2: Add negative and positive gate scenarios**

The script creates isolated generated projects and verifies fresh plan failure,
completed plan success, dependency blocking, risk-`H` prototype-`NA` rejection,
smoke failure rejection, open P0/P1 rejection, high-risk approval enforcement,
GitHub approval enforcement, complete release success, and retrospective
evidence enforcement.

- [x] **Step 3: Run the lifecycle test and verify failure**

Run: `bash tests/test-lifecycle-gates.sh`

Expected: non-zero exit because `scripts/check-lifecycle-gate.sh` is absent.

### Task 4: Implement the lifecycle gate validator

**Files:**

- Create: `templates/scripts/check-lifecycle-gate.sh`
- Modify: `templates/scripts/check-harness.sh`
- Test: `tests/test-lifecycle-gates.sh`

- [x] **Step 1: Implement safe state parsing and primitive assertions**

```bash
state_value() {
  local key="$1" count
  count="$(awk -F= -v key="$key" '$1 == key { count++ } END { print count + 0 }' "$STATE_FILE")"
  [[ "$count" == 1 ]] || fail "State key must occur exactly once: $key"
  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print }' "$STATE_FILE"
}

require_complete_file() {
  local relative="$1" path="$ROOT_DIR/$relative"
  [[ -f "$path" ]] || fail "Missing lifecycle evidence: $relative"
  ! grep -Fq '<!-- REQUIRED:' "$path" || fail "Required evidence is incomplete: $relative"
  ! grep -Eq '(^|[^A-Za-z])TBD([^A-Za-z]|$)' "$path" || fail "Placeholder remains: $relative"
}
```

- [x] **Step 2: Implement gate dependency functions**

Implement `check_plan`, `check_design`, `check_prototype`,
`check_implementation`, `check_release`, `check_github`, and
`check_retrospective`. Each function calls its predecessor before validating
its own state and evidence. `check_prototype` handles `PASS` and allowed `NA`;
`check_release` requires `HUMAN_APPROVAL_REF` for risk `H`; `check_github`
requires `APPROVED` plus `GITHUB_APPROVAL_REF`.

- [x] **Step 3: Reject critical open findings**

```bash
if grep -Eq '^\|[[:space:]]*P[01][[:space:]]*\|[[:space:]]*OPEN[[:space:]]*\|' \
  "$ROOT_DIR/docs/lifecycle/ADVERSARIAL_REVIEW.md"; then
  fail "Open P0/P1 adversarial findings block the gate"
fi
```

- [x] **Step 4: Extend structural validation**

Add every lifecycle template, `.ai/LIFECYCLE_STATE`, and the gate script to
`required_files`; run `bash -n` on both scripts; require the gate script to be
executable.

- [x] **Step 5: Run lifecycle and generator tests**

Run: `bash tests/test-lifecycle-gates.sh && bash tests/test-new-full-project.sh`

Expected: both scripts exit zero and print their `ok` messages.

### Task 5: Integrate the lifecycle into rules, workflow, and documentation

**Files:**

- Modify: `templates/.ai/PROJECT_CONTEXT.md`
- Modify: `templates/.ai/PROJECT_RULES.md`
- Modify: `templates/.ai/WORKFLOW.md`
- Modify: `templates/.ai/PROJECT_HISTORY.md`
- Modify: `templates/docs/product/PRD.md`
- Modify: `templates/docs/technical/TECHNICAL_PRD.md`
- Modify: `README.md`
- Modify: `tests/test-new-full-project.sh`

- [x] **Step 1: Add failing content assertions**

Require generated rules and workflow to mention `LIFECYCLE_STATE`, risk levels,
all four methods, gate commands, no-silent-bypass behavior, Stage 7, and
enforcement limitations.

- [x] **Step 2: Update context and rule source**

Add the risk level and lifecycle evidence index to context. In rules, define
risk escalation, mandatory artifacts, exact gate commands, dependency reset,
`NA` restrictions, exception handling, and the external-control boundary.

- [x] **Step 3: Update stage execution instructions**

Make every stage name its applied methods, evidence updates, validator command,
and stop condition. Add Stage 7 retrospective.

- [x] **Step 4: Strengthen PRD templates**

Product PRD gains core outcome, non-goals, success metrics, constraints, failure
states, and rejected pseudo-requirements. Technical PRD gains assumptions,
alternatives, failure and rollback design, trust boundaries, observability,
adversarial review, and verification mapping.

- [x] **Step 5: Run tests**

Run: `bash tests/test-new-full-project.sh && bash tests/test-lifecycle-gates.sh`

Expected: both scripts exit zero.

### Task 6: Perform harness-on-itself adversarial verification

**Files:**

- Inspect: all changed files
- Test: `tests/test-new-full-project.sh`
- Test: `tests/test-lifecycle-gates.sh`

- [x] **Step 1: Run shell syntax validation**

Run:

```bash
bash -n bin/new-full-project bin/install-ai-full-harness \
  templates/scripts/check-harness.sh \
  templates/scripts/check-lifecycle-gate.sh \
  tests/test-new-full-project.sh tests/test-lifecycle-gates.sh
```

Expected: exit zero with no output.

- [x] **Step 2: Run the complete test suite**

Run: `bash tests/test-new-full-project.sh && bash tests/test-lifecycle-gates.sh`

Expected: both scripts print `ok` and exit zero.

- [x] **Step 3: Inspect generated output and executable modes**

Generate a temporary `M` project, run `scripts/check-harness.sh`, verify fresh
`plan` is blocked, complete the controlled fixture, and validate the release
chain. Inspect `git diff --check`, `git status --short`, and `git diff --stat`.

- [x] **Step 4: Review the guarantee boundary**

Confirm documentation distinguishes mechanical guarantees from semantic and
external enforcement, and report that branch protection, required CI checks,
deployment permissions, and genuine human identity are outside the local
harness trust boundary.
