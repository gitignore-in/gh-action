#!/bin/sh
# Apply required-status-checks to the default-branch-baseline ruleset.
#
# Usage: ./scripts/configure-branch-ruleset.sh [--dry-run]
#
# Requires: gh CLI with admin token (repo scope).
# The ruleset is identified by name; the script fetches its ID automatically.
#
# Expected required checks (matching .github/workflows/*.yml job names):
#   shell-format, check, shell-lint,
#   diff-detection (ubuntu-latest), diff-detection (macos-latest),
#   test, test (boilerplates_ref passthrough), timeout helper

set -eu

REPO="gitignore-in/gh-action"
RULESET_NAME="default-branch-baseline"
DRY_RUN=false

if [ "${1:-}" = "--dry-run" ]; then
	DRY_RUN=true
fi

ruleset_id=$(gh api "repos/${REPO}/rulesets" |
	jq -r --arg name "${RULESET_NAME}" '.[] | select(.name == $name) | .id')

if [ -z "${ruleset_id}" ]; then
	echo "Error: ruleset '${RULESET_NAME}' not found" >&2
	exit 1
fi

required_checks='[
  {"context":"shell-format"},
  {"context":"check"},
  {"context":"shell-lint"},
  {"context":"diff-detection (ubuntu-latest)"},
  {"context":"diff-detection (macos-latest)"},
  {"context":"test"},
  {"context":"test (boilerplates_ref passthrough)"},
  {"context":"timeout helper"}
]'

current_sorted=$(gh api "repos/${REPO}/rulesets/${ruleset_id}" |
	jq -r '[.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks[].context] | sort | @json')
desired_sorted=$(printf '%s' "${required_checks}" | jq -r '[.[].context] | sort | @json')

if [ "${current_sorted}" = "${desired_sorted}" ]; then
	echo "required_status_checks already up-to-date in ruleset ${ruleset_id}"
	exit 0
fi

if "${DRY_RUN}"; then
	echo "Dry run: would update required_status_checks in ruleset ${ruleset_id}"
	echo "${required_checks}"
	exit 0
fi

tmpfile=$(mktemp)
trap 'rm -f "${tmpfile}"' EXIT

gh api "repos/${REPO}/rulesets/${ruleset_id}" \
	--jq '{
    rules: ([.rules[] | select(.type != "required_status_checks")] + [{
      type: "required_status_checks",
      parameters: {
        strict_required_status_checks_policy: false,
        required_status_checks: '"${required_checks}"'
      }
    }])
  }' >"${tmpfile}"

gh api -X PUT "repos/${REPO}/rulesets/${ruleset_id}" \
	--input "${tmpfile}" >/dev/null

echo "Updated required_status_checks in ruleset ${ruleset_id} (${RULESET_NAME})"
