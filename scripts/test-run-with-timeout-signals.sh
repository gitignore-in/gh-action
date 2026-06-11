#!/usr/bin/env bash
set -euo pipefail

if ! command -v setsid >/dev/null 2>&1; then
	echo "setsid unavailable; skipping process-group cancellation test"
	exit 0
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "${tmpdir}"' EXIT
marker="${tmpdir}/writes"
: >"${marker}"

scripts/run-with-timeout.sh 30 bash -c "trap '' TERM; (trap '' TERM; while true; do printf x >> \"\$1\"; sleep 0.2; done) & wait" _ "${marker}" &
wrapper_pid=$!

for _ in 1 2 3 4 5; do
	if [ -s "${marker}" ]; then
		break
	fi
	sleep 0.2
done
[ -s "${marker}" ]

kill -TERM "${wrapper_pid}"
set +e
wait "${wrapper_pid}"
status=$?
set -e
[ "${status}" -eq 143 ]

bytes_after_wait="$(wc -c <"${marker}" | tr -d ' ')"
sleep 1
bytes_after_sleep="$(wc -c <"${marker}" | tr -d ' ')"
[ "${bytes_after_wait}" = "${bytes_after_sleep}" ]
