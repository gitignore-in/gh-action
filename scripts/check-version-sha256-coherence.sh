#!/usr/bin/env bash
set -euo pipefail

# Verify that the version referenced in action.yml matches every entry in
# bundled-binary.sha256. When a Renovate PR updates only the bundled_version=
# line in action.yml without regenerating bundled-binary.sha256, the download
# step fails at workflow runtime because grep finds no matching checksum line.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

action_file="${repo_root}/action.yml"
sha256_file="${repo_root}/bundled-binary.sha256"

action_version="$(grep -E '^\s+bundled_version="v[0-9]+\.[0-9]+\.[0-9]+"$' "${action_file}" | sed -E 's/.*bundled_version="(v[0-9]+\.[0-9]+\.[0-9]+)".*/\1/')"
if [ -z "${action_version}" ]; then
	echo "ERROR: could not extract bundled_version= from ${action_file}" >&2
	exit 1
fi
echo "action.yml version: ${action_version}"

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
