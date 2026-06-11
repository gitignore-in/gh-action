#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
validator="${SCRIPT_DIR}/validate-pull-request-metadata.sh"

expect_success() {
	env \
		GITIGNORE_IN_COMMIT_MESSAGE='Update .gitignore' \
		GITIGNORE_IN_PR_TITLE='Update .gitignore' \
		GITIGNORE_IN_PR_BODY=$'Generated body\n\n- item' \
		"${validator}"
}

expect_failure() {
	local expected="$1"
	shift
	local output
	local status

	set +e
	output="$("$@" 2>&1)"
	status=$?
	set -e

	if [ "${status}" -eq 0 ]; then
		echo "expected failure for ${expected}" >&2
		exit 1
	fi
	if ! grep -Fq "${expected}" <<<"${output}"; then
		echo "expected error containing '${expected}', got: ${output}" >&2
		exit 1
	fi
}

expect_success

expect_failure 'commit_message must be single-line text' env \
	GITIGNORE_IN_COMMIT_MESSAGE=$'Update\n.gitignore' \
	GITIGNORE_IN_PR_TITLE='Update .gitignore' \
	GITIGNORE_IN_PR_BODY='Generated body' \
	"${validator}"

expect_failure 'pr_title must not contain ASCII control characters' env \
	GITIGNORE_IN_COMMIT_MESSAGE='Update .gitignore' \
	GITIGNORE_IN_PR_TITLE=$'Update \001.gitignore' \
	GITIGNORE_IN_PR_BODY='Generated body' \
	"${validator}"

expect_failure 'pr_body must not contain ASCII control characters' env \
	GITIGNORE_IN_COMMIT_MESSAGE='Update .gitignore' \
	GITIGNORE_IN_PR_TITLE='Update .gitignore' \
	GITIGNORE_IN_PR_BODY=$'Generated \001body' \
	"${validator}"
