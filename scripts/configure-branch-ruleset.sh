#!/usr/bin/env bash
# Apply required-status-checks to the default-branch-baseline ruleset.
#
# Usage: ./scripts/configure-branch-ruleset.sh [--dry-run]
#
# Requires: gh CLI with admin token (repo scope).
# The ruleset is identified by name; the script fetches its ID automatically.
#
# Expected required checks (matching .github/workflows/*.yml job names):
#   shell-format, check, shell-lint, version-coherence,
#   diff-detection (ubuntu-latest), diff-detection (macos-latest),
#   test, test (boilerplates_ref passthrough), timeout helper,
#   version-coherence

set -euo pipefail

REPO="gitignore-in/gh-action"
RULESET_NAME="default-branch-baseline"
DRY_RUN=false

if [ "${1:-}" = "--dry-run" ]; then
	DRY_RUN=true
fi

ruleset_ids=$(gh api "repos/${REPO}/rulesets" |
	jq -r --arg name "${RULESET_NAME}" '.[] | select(.name == $name) | .id')

ruleset_count=$(printf '%s\n' "${ruleset_ids}" | sed '/^$/d' | wc -l | tr -d ' ')

if [ "${ruleset_count}" -eq 0 ]; then
	echo "Error: ruleset '${RULESET_NAME}' not found" >&2
	exit 1
fi

if [ "${ruleset_count}" -ne 1 ]; then
	echo "Error: expected exactly one ruleset named '${RULESET_NAME}', found ${ruleset_count}" >&2
	printf 'Matching ruleset IDs:\n%s\n' "${ruleset_ids}" >&2
	exit 1
fi

ruleset_id=$(printf '%s\n' "${ruleset_ids}" | sed -n '1p')

required_checks='[
  {"context":"shell-format"},
  {"context":"check"},
  {"context":"shell-lint"},
  {"context":"version-coherence"},
  {"context":"diff-detection (ubuntu-latest)"},
  {"context":"diff-detection (macos-latest)"},
  {"context":"test"},
  {"context":"test (boilerplates_ref passthrough)"},
  {"context":"timeout helper"},
  {"context":"version-coherence"}
]'

current_sorted=$(gh api "repos/${REPO}/rulesets/${ruleset_id}" |
	jq -r '[.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks[].context] | sort | @json')
desired_sorted=$(printf '%s' "${required_checks}" | jq -r '[.[].context] | sort | @json')

if [ "${current_sorted}" = "${desired_sorted}" ]; then
	echo "required_status_checks already up-to-date in ruleset ${ruleset_id}" >&2
	exit 0
fi

if "${DRY_RUN}"; then
	echo "Dry run: would update required_status_checks in ruleset ${ruleset_id}" >&2
	echo "${required_checks}"
	exit 0
fi

tmpfile=$(mktemp)
trap 'rm -f "${tmpfile}"' EXIT

gh api "repos/${REPO}/rulesets/${ruleset_id}" |
	jq --argjson rc "${required_checks}" '{
    rules: ([.rules[] | select(.type != "required_status_checks")] + [{
      type: "required_status_checks",
      parameters: {
        strict_required_status_checks_policy: false,
        required_status_checks: $rc
      }
    }])
  }' >"${tmpfile}"

if ! jq -e '.rules | arrays' "${tmpfile}" >/dev/null 2>&1; then
	echo "Error: ruleset JSON construction failed; aborting PUT" >&2
	exit 1
fi

gh api -X PUT "repos/${REPO}/rulesets/${ruleset_id}" \
	--input "${tmpfile}" >/dev/null

echo "Updated required_status_checks in ruleset ${ruleset_id} (${RULESET_NAME})" >&2
