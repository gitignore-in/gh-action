#!/usr/bin/env bash
set -euo pipefail

version="${1:-${GITIGNORE_IN_VERSION:-}}"
if [ -z "${version}" ]; then
	echo "usage: $0 <version>" >&2
	exit 1
fi

if ! [[ "${version}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	echo "version must use vMAJOR.MINOR.PATCH format: ${version}" >&2
	exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

sed -i.bak \
	-e "s/version=v[0-9][0-9.]*$/version=${version}/" \
	"${repo_root}/action.yml"

rm -f "${repo_root}/action.yml.bak"

# Regenerate bundled-binary.sha256 against the upstream release tarballs so
# the action's wget step can verify each platform's bytes before extracting.
archs=(
	"x86_64-unknown-linux-gnu"
	"aarch64-unknown-linux-gnu"
	"x86_64-apple-darwin"
	"aarch64-apple-darwin"
)

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

release_url="https://github.com/gitignore-in/gitignore-in/releases/download/${version}"
checksum_file="${repo_root}/bundled-binary.sha256"
: >"${checksum_file}"

for arch in "${archs[@]}"; do
	target="gitignore-in-${arch}-${version}.tar.gz"
	curl --fail --location --silent --show-error --output "${tmpdir}/${target}" "${release_url}/${target}"
	(cd "${tmpdir}" && shasum -a 256 "${target}") >>"${checksum_file}"
done
