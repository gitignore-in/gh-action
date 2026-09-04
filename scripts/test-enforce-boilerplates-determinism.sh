#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
checker="${script_dir}/enforce-boilerplates-determinism.sh"

test_empty_ref_warns_by_default() {
	local output status
	set +e
	output="$(BOILERPLATES_REF="" REQUIRE_BOILERPLATES_REF="" "${checker}" 2>&1)"
	status=$?
	set -e

	if [ "${status}" -ne 0 ]; then
		echo "expected empty boilerplates_ref without require flag to succeed" >&2
		echo "${output}" >&2
		exit 1
	fi
	if ! grep -F -- "::warning::boilerplates_ref is not set" <<<"${output}" >/dev/null; then
		echo "expected non-determinism warning" >&2
		echo "${output}" >&2
		exit 1
	fi
}

test_empty_ref_fails_when_required() {
	local output status
	set +e
	output="$(BOILERPLATES_REF="" REQUIRE_BOILERPLATES_REF="true" "${checker}" 2>&1)"
	status=$?
	set -e

	if [ "${status}" -eq 0 ]; then
		echo "expected empty boilerplates_ref with require_boilerplates_ref=true to fail" >&2
		exit 1
	fi
	if [ "${status}" -ne 1 ]; then
		echo "expected exit 1, got ${status}" >&2
		echo "${output}" >&2
		exit 1
	fi
	if ! grep -F -- "::error::boilerplates_ref is not set and require_boilerplates_ref=true" <<<"${output}" >/dev/null; then
		echo "expected explicit determinism error" >&2
		echo "${output}" >&2
		exit 1
	fi
}

test_pinned_ref_never_warns_or_fails() {
	local output status

	for require in "" "true" "false"; do
		set +e
		output="$(BOILERPLATES_REF="main" REQUIRE_BOILERPLATES_REF="${require}" "${checker}" 2>&1)"
		status=$?
		set -e

		if [ "${status}" -ne 0 ]; then
			echo "expected pinned boilerplates_ref (require_boilerplates_ref='${require}') to succeed" >&2
			echo "${output}" >&2
			exit 1
		fi
		if [ -n "${output}" ]; then
			echo "expected no warning/error output when boilerplates_ref is pinned (require_boilerplates_ref='${require}')" >&2
			echo "${output}" >&2
			exit 1
		fi
	done
}

test_empty_ref_warns_by_default
test_empty_ref_fails_when_required
test_pinned_ref_never_warns_or_fails
