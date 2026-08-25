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

# Compares significant lines in order (not just as a multiset), so that a
# reordering of lines around a negation pattern (e.g. `!keep.log` moved
# before/after the rule it negates) is treated as meaningful even when the
# same set of lines is added and removed the same number of times.
filter_significant() {
	sed -e 's/[[:space:]]*$//' |
		awk '$0 !~ /^[[:space:]]*($|#)/'
}

old_content="$(git show ":${target}" | filter_significant)"
new_content="$(filter_significant <"${target}")"

if [ "${old_content}" != "${new_content}" ]; then
	echo "changed=true" >>"${GITHUB_OUTPUT:-/dev/stdout}"
else
	echo "changed=false" >>"${GITHUB_OUTPUT:-/dev/stdout}"
fi
