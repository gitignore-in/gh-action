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

# setsid(1) places the command in a new session so that killing the process
# group (kill -- -$pid) reaches the command and all its descendants.
# On platforms where setsid is unavailable (e.g. macOS), fall back to starting
# the command directly; in that case only the top-level PID is signalled.
if command -v setsid >/dev/null 2>&1; then
	setsid "$@" &
else
	"$@" &
fi
command_pid=$!

(
	sleep "${timeout_seconds}"
	if kill -0 "${command_pid}" 2>/dev/null; then
		printf 'command timed out after %ss: %s\n' "${timeout_seconds}" "${command_display}" >&2
		: >"${timeout_marker}"
		# Signal the whole process group first; fall back to the direct PID.
		kill -- -"${command_pid}" 2>/dev/null || kill "${command_pid}" 2>/dev/null || true
		# SIGKILL fallback: give the process up to 5 s to exit gracefully.
		sleep 5
		if kill -0 "${command_pid}" 2>/dev/null; then
			kill -9 -- -"${command_pid}" 2>/dev/null || kill -9 "${command_pid}" 2>/dev/null || true
		fi
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
