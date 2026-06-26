#!/usr/bin/env bash
set -euo pipefail

boilerplates_dir="${1:-${HOME}/.gitignore-boilerplates}"
ref=""

if git -C "${boilerplates_dir}" rev-parse --git-dir > /dev/null 2>&1; then
	ref="$(git -C "${boilerplates_dir}" rev-parse --verify HEAD)"
	if ! [[ "${ref}" =~ ^([0-9a-f]{40}|[0-9a-f]{64})$ ]]; then
		echo "Unexpected boilerplates HEAD ref; leaving boilerplates-ref empty" >&2
		ref=""
	fi
fi

printf 'boilerplates-ref=%s\n' "${ref}" >>"${GITHUB_OUTPUT:-/dev/stdout}"
