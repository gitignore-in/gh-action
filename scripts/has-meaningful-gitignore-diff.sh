#!/usr/bin/env bash
set -euo pipefail

target="${1:-.gitignore}"

# Untracked (newly generated) file is always a meaningful change.
if git ls-files --others -- "${target}" | grep -q .; then
	echo "changed=true" >>"${GITHUB_OUTPUT:-/dev/stdout}"
	exit 0
fi

if ! git diff --name-only -- "${target}" | grep -q .; then
	echo "changed=false" >>"${GITHUB_OUTPUT:-/dev/stdout}"
	exit 0
fi

if git diff -- "${target}" |
	grep '^[+-][^+-]' |
	grep -vq -e '^[+-][[:space:]]*#' -e '^[+-][[:space:]]*$'; then
	echo "changed=true" >>"${GITHUB_OUTPUT:-/dev/stdout}"
else
	echo "changed=false" >>"${GITHUB_OUTPUT:-/dev/stdout}"
fi
