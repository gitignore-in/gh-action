#!/usr/bin/env bash
set -euo pipefail

script="scripts/update-version.sh"

expect_usage_error() {
	local description="$1"
	local expected="$2"
	shift 2

	local output
	local status
	set +e
	output="$("$@" 2>&1 >/dev/null)"
	status=$?
	set -e

	if [ "${status}" -ne 2 ]; then
		echo "${description}: expected exit 2, got ${status}" >&2
		printf '%s\n' "${output}" >&2
		exit 1
	fi
	if ! grep -F -- "${expected}" <<<"${output}" >/dev/null; then
		echo "${description}: expected diagnostic containing '${expected}'" >&2
		printf '%s\n' "${output}" >&2
		exit 1
	fi
}

expect_usage_error "missing version" "usage:" env -u GITIGNORE_IN_VERSION "$script"
expect_usage_error "invalid argument version" "version must use vMAJOR.MINOR.PATCH format: not-a-version" "$script" not-a-version
expect_usage_error "invalid environment version" "version must use vMAJOR.MINOR.PATCH format: not-a-version" env GITIGNORE_IN_VERSION=not-a-version "$script"
