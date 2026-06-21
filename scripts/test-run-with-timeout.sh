#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
run_with_timeout="${RUN_WITH_TIMEOUT_BIN:-${script_dir}/run-with-timeout.sh}"

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

	# shellcheck disable=SC2329 # Invoked by the child bash running run-with-timeout.sh.
	kill() {
		local pid
		local target

		if [ "${1:-}" = "-TERM" ] && [ -n "${RUN_WITH_TIMEOUT_RACE_PROBE:-}" ]; then
			for target in "$@"; do :; done
			pid="${target#-}"
			if [[ "${pid}" =~ ^[0-9]+$ ]]; then
				: >"${RUN_WITH_TIMEOUT_RACE_PROBE}"
				for _ in 1 2 3 4 5 6 7 8 9 10; do
					if ! builtin kill -0 "${pid}" 2>/dev/null; then
						break
					fi
					sleep 0.1
				done
			fi
		fi

		builtin kill "$@"
	}
	export -f kill
	export RUN_WITH_TIMEOUT_RACE_PROBE="${probe}"

	set +e
	# shellcheck disable=SC2016 # The child command reads RUN_WITH_TIMEOUT_RACE_PROBE.
	"${run_with_timeout}" 1 bash -c 'while [ ! -f "${RUN_WITH_TIMEOUT_RACE_PROBE}" ]; do sleep 0.01; done; exit 0'
	status=$?
	set -e

	unset -f kill
	unset RUN_WITH_TIMEOUT_RACE_PROBE
	rm -f "${probe}"

	[ "${status}" -eq 0 ]
}

test_preserves_command_exit_status
test_exits_124_when_command_exceeds_timeout
test_preserves_normal_exit_during_timeout_race
