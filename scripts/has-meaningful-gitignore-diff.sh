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

if git diff --ignore-space-at-eol -- "${target}" |
	awk '
		/^diff --git / { in_hunk = 0; next }
		/^@@ / { in_hunk = 1; next }
		in_hunk && /^[+-]/ {
			content = substr($0, 2)
			if (content !~ /^[[:space:]]*(#|$)/) {
				found = 1
			}
		}
		END { exit found ? 0 : 1 }
	'; then
	echo "changed=true" >>"${GITHUB_OUTPUT:-/dev/stdout}"
else
	echo "changed=false" >>"${GITHUB_OUTPUT:-/dev/stdout}"
fi
