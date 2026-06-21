#!/usr/bin/env bash
set -euo pipefail

action_file="${1:-action.yml}"

version="$(
	awk '
		$1 == "gitignore-version:" { in_section = 1; next }
		in_section && $1 == "default:" {
			gsub(/"/, "", $2)
			print $2
			exit
		}
	' "${action_file}"
)"
if [ -z "${version}" ]; then
	echo "ERROR: could not extract inputs.gitignore-version default from ${action_file}" >&2
	exit 1
fi

printf '%s\n' "${version}"
