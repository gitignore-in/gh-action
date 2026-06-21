#!/usr/bin/env bash
set -euo pipefail

# Verify that the bundled gitignore-version declared in action.yml matches
# every entry in bundled-binary.sha256. When action.yml and the checksum file
# drift, the download step fails at workflow runtime because the expected
# checksum line cannot be found.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

action_file="${repo_root}/action.yml"
sha256_file="${repo_root}/bundled-binary.sha256"

<<<<<<< HEAD
action_version="$(
	awk '
		$1 == "gitignore-version:" { in_section = 1; next }
		in_section && $1 == "default:" {
			gsub(/"/, "", $2)
			print $2
			exit
		}
	' "${action_file}"
)"
if [ -z "${action_version}" ]; then
	echo "ERROR: could not extract inputs.gitignore-version default from ${action_file}" >&2
	exit 1
fi
echo "action.yml bundled_version: ${action_version}"

total="$(grep -c . "${sha256_file}" || true)"
if [ "${total}" -eq 0 ]; then
	echo "ERROR: ${sha256_file} is empty" >&2
	exit 1
fi

matching="$(grep -cF "${action_version}" "${sha256_file}" || true)"
echo "bundled-binary.sha256: ${matching}/${total} entries match ${action_version}"

if [ "${matching}" -ne "${total}" ]; then
	echo "ERROR: version mismatch — action.yml references ${action_version}" >&2
	echo "       but ${total} entries exist and only ${matching} contain ${action_version}" >&2
	echo "       Run scripts/update-version.sh ${action_version} to regenerate bundled-binary.sha256" >&2
	exit 1
fi

echo "OK: all ${total} entries in bundled-binary.sha256 are coherent with ${action_version}"
