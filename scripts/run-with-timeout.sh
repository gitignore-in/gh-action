#!/usr/bin/env bash
set -euo pipefail

timeout_seconds="${1:-}"
if [ -z "${timeout_seconds}" ] || ! [[ "${timeout_seconds}" =~ ^[0-9]+$ ]] || [ "${timeout_seconds}" -eq 0 ]; then
	echo "usage: $0 <positive-timeout-seconds> <command> [args...]" >&2
	exit 2
fi
shift

if [ "$#" -eq 0 ]; then
	echo "usage: $0 <positive-timeout-seconds> <command> [args...]" >&2
	exit 2
fi

command_display="$*"
tmpdir="$(mktemp -d)"
timeout_marker="${tmpdir}/timed-out"
trap 'rm -rf "${tmpdir}"' EXIT

"$@" &
command_pid=$!

(
	sleep "${timeout_seconds}"
	if kill -0 "${command_pid}" 2>/dev/null; then
		printf 'command timed out after %ss: %s\n' "${timeout_seconds}" "${command_display}" >&2
		: >"${timeout_marker}"
		kill "${command_pid}" 2>/dev/null || true
	fi
) &
watchdog_pid=$!

set +e
wait "${command_pid}" 2>/dev/null
status=$?
set -e

kill "${watchdog_pid}" 2>/dev/null || true
wait "${watchdog_pid}" 2>/dev/null || true

if [ -f "${timeout_marker}" ]; then
	exit 124
fi

exit "${status}"
