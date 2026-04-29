#!/usr/bin/env bash
set -euo pipefail

target="${1:-.gitignore}"

if ! git diff --name-only -- "${target}" | grep -q .; then
	echo "changed=false" >>"${GITHUB_OUTPUT:-/dev/stdout}"
	exit 0
fi

if git diff -- "${target}" |
	grep '^[+-][^+-]' |
	grep -vq -e '^[+-]\s*#' -e '^$'; then
	echo "changed=true" >>"${GITHUB_OUTPUT:-/dev/stdout}"
else
	echo "changed=false" >>"${GITHUB_OUTPUT:-/dev/stdout}"
fi
