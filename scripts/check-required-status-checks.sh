#!/usr/bin/env bash
# Verify that the default branch ruleset only requires checks produced by a PR.

set -euo pipefail

REPO="${GITHUB_REPOSITORY:-gitignore-in/gh-action}"
RULESET_NAME="default-branch-baseline"
PR_NUMBER="${PR_NUMBER:-}"

usage() {
	echo "Usage: $0 [--repo owner/repo] [--ruleset-name name] [--pr number]"
}

while [ "$#" -gt 0 ]; do
	case "$1" in
	--repo)
		if [ "$#" -lt 2 ]; then
			usage >&2
			exit 2
		fi
		REPO="$2"
		shift 2
		;;
	--ruleset-name)
		if [ "$#" -lt 2 ]; then
			usage >&2
			exit 2
		fi
		RULESET_NAME="$2"
		shift 2
		;;
	--pr)
		if [ "$#" -lt 2 ]; then
			usage >&2
			exit 2
		fi
		PR_NUMBER="$2"
		shift 2
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "Error: unknown argument: $1" >&2
		usage >&2
		exit 2
		;;
	esac
done

if [ -z "${PR_NUMBER}" ] && [ -n "${GITHUB_EVENT_PATH:-}" ] && [ -f "${GITHUB_EVENT_PATH}" ]; then
	PR_NUMBER=$(jq -r '.pull_request.number // empty' "${GITHUB_EVENT_PATH}")
fi

if [ -z "${PR_NUMBER}" ]; then
	echo "Error: pull request number is required" >&2
	usage
	exit 2
fi

ruleset_ids=$(gh api "repos/${REPO}/rulesets" \
	--jq ".[] | select(.name == \"${RULESET_NAME}\") | .id")

if [ -z "${ruleset_ids}" ]; then
	echo "Error: ruleset '${RULESET_NAME}' not found in ${REPO}" >&2
	exit 1
fi

ruleset_count=$(printf '%s\n' "${ruleset_ids}" | sed '/^$/d' | wc -l | tr -d ' ')
if [ "${ruleset_count}" -ne 1 ]; then
	echo "Error: ruleset '${RULESET_NAME}' matched ${ruleset_count} rulesets in ${REPO}" >&2
	exit 1
fi

ruleset_id=$(printf '%s\n' "${ruleset_ids}" | sed -n '1p')

tmpdir=$(mktemp -d)
trap 'rm -rf "${tmpdir}"' EXIT

required_checks_file="${tmpdir}/required-checks"
pr_checks_file="${tmpdir}/pr-checks"

gh api "repos/${REPO}/rulesets/${ruleset_id}" \
	--jq '.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks[].context' |
	sort -u >"${required_checks_file}"

if [ ! -s "${required_checks_file}" ]; then
	echo "Error: ruleset '${RULESET_NAME}' has no required_status_checks entries" >&2
	exit 1
fi

set +e
gh pr checks "${PR_NUMBER}" --repo "${REPO}" --json name --jq '.[].name' >"${pr_checks_file}"
checks_status=$?
set -e

# gh pr checks exits with code 8 when the PR has no checks (empty list).
# This is not an error condition here — a PR with no checks simply produces an
# empty file, which is handled correctly by the diff below.
if [ "${checks_status}" -ne 0 ] && [ "${checks_status}" -ne 8 ]; then
	echo "Error: failed to list checks for ${REPO}#${PR_NUMBER}" >&2
	exit "${checks_status}"
fi

sort -u "${pr_checks_file}" -o "${pr_checks_file}"

missing=0
while IFS= read -r required_check; do
	if ! grep -Fx -- "${required_check}" "${pr_checks_file}" >/dev/null; then
		echo "Missing required status check context: ${required_check}" >&2
		missing=1
	fi
done <"${required_checks_file}"

if [ "${missing}" -ne 0 ]; then
	echo "Ruleset '${RULESET_NAME}' requires checks that this PR does not produce." >&2
	echo "Update the ruleset or restore the workflow job names before merging." >&2
	exit 1
fi

echo "All required status check contexts are produced by ${REPO}#${PR_NUMBER}."
