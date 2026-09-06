#!/usr/bin/env bash
set -euo pipefail

boilerplates_ref="${BOILERPLATES_REF:-${1:-}}"
require_boilerplates_ref="${REQUIRE_BOILERPLATES_REF:-${2:-false}}"

if [ -n "${boilerplates_ref}" ]; then
	exit 0
fi

if [ "${require_boilerplates_ref}" = "true" ]; then
	echo "::error::boilerplates_ref is not set and require_boilerplates_ref=true; set boilerplates_ref to a pinned ref (branch, tag, or full SHA) of the boilerplates database to get a deterministic .gitignore." >&2
	exit 1
fi

echo "::warning::boilerplates_ref is not set; generated pull requests will record the latest boilerplates database commit SHA, but the generated .gitignore may vary between runs. Set require_boilerplates_ref=true to turn this into a hard failure until boilerplates_ref is pinned."
