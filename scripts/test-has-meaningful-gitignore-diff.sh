#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
helper="${repo_root}/scripts/has-meaningful-gitignore-diff.sh"

run_tracked_case() {
	local name="$1"
	local expected="$2"
	local initial="$3"
	local updated="$4"
	local tmpdir

	tmpdir="$(mktemp -d)"
	(
		trap 'rm -rf "${tmpdir}"' EXIT
		cd "${tmpdir}"

		git init --quiet
		git config user.name test
		git config user.email test@example.com
		printf '%s' "${initial}" >.gitignore
		git add .gitignore
		git commit --quiet -m init
		printf '%s' "${updated}" >.gitignore

		GITHUB_OUTPUT="${tmpdir}/output.txt" "${helper}" .gitignore
		if ! grep -qx "changed=${expected}" "${tmpdir}/output.txt"; then
			echo "${name}: expected changed=${expected}" >&2
			cat "${tmpdir}/output.txt" >&2
			exit 1
		fi
	)
}

run_tracked_case \
	"leading whitespace change is meaningful" \
	true \
	$'node_modules/\n.env\n' \
	$'node_modules/\n  .env\n'

run_tracked_case \
	"literal hash pattern change is meaningful" \
	true \
	$'node_modules/\n.env\n' \
	$'node_modules/\n\\#build\n'

run_tracked_case \
	"changed pattern is meaningful" \
	true \
	$'node_modules/\n.env\n' \
	$'node_modules/\nbuild/\n'
