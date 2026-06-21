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
<<<<<<< HEAD
action_version="$("${script_dir}/read-bundled-gitignore-version.sh" "${action_file}")"
echo "action.yml version: ${action_version}"
=======
action_version="$("${script_dir}/read-bundled-gitignore-version.sh" "${action_file}")"
echo "action.yml version: ${action_version}"
>>>>>>> 3a53cbc (Use action metadata as bundled version source)

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
