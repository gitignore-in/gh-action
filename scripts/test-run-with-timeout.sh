#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
run_with_timeout="${script_dir}/run-with-timeout.sh"

test_preserves_command_exit_status() {
	local status

	set +e
	"${run_with_timeout}" 5 bash -c 'exit 7'
	status=$?
	set -e

	[ "${status}" -eq 7 ]
}

test_exits_124_when_command_exceeds_timeout() {
	local status

	set +e
	"${run_with_timeout}" 1 bash -c 'sleep 5'
	status=$?
	set -e

	[ "${status}" -eq 124 ]
}

test_preserves_normal_exit_during_timeout_race() {
	local probe
	local status

	probe="$(mktemp)"
	rm -f "${probe}"
	trap 'rm -f "${probe}"' RETURN

	# shellcheck disable=SC2329
	kill() {
		local result

		if [ "${1:-}" = "-0" ] && [ -n "${RUN_WITH_TIMEOUT_RACE_PROBE:-}" ]; then
			set +e
			builtin kill "$@"
			result=$?
			set -e
			if [ "${result}" -eq 0 ]; then
				: >"${RUN_WITH_TIMEOUT_RACE_PROBE}"
				sleep 0.2
			fi
			return "${result}"
		fi

		builtin kill "$@"
	}
	export -f kill
	export RUN_WITH_TIMEOUT_RACE_PROBE="${probe}"

	set +e
	# shellcheck disable=SC2016
	"${run_with_timeout}" 1 bash -c 'while [ ! -f "${RUN_WITH_TIMEOUT_RACE_PROBE}" ]; do sleep 0.01; done; exit 0'
	status=$?
	set -e

	unset -f kill
	unset RUN_WITH_TIMEOUT_RACE_PROBE

	[ "${status}" -eq 0 ]
}

test_preserves_command_exit_status
test_exits_124_when_command_exceeds_timeout
test_preserves_normal_exit_during_timeout_race
