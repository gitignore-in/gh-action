#!/usr/bin/env bash
set -euo pipefail

version="${1:-${GITIGNORE_IN_VERSION:-}}"
if [ -z "${version}" ]; then
	echo "usage: $0 <version>" >&2
	exit 1
fi

sed -i.bak \
	-e "s/version=v[0-9][0-9.]*$/version=${version}/" \
	action.yml

rm -f action.yml.bak
