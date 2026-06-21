#!/usr/bin/env bash
set -euo pipefail

version="${1:-${GITIGNORE_IN_VERSION:-}}"
if [ -z "${version}" ]; then
	echo "usage: $0 <version>" >&2
	exit 2
fi

if ! [[ "${version}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
	echo "version must use vMAJOR.MINOR.PATCH format: ${version}" >&2
	exit 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

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
action_file="${repo_root}/action.yml"
# Build the new checksum file in tmpdir first; only mutate the in-repo files
# once every platform has been fetched and hashed. A partial failure must not
# leave action.yml pinned to a new version while bundled-binary.sha256 still
# carries the old one (or vice versa), because that combination silently fails
# at consumer workflow run time instead of at update-version.sh time.
staging_file="${tmpdir}/bundled-binary.sha256"
: >"${staging_file}"

curl_connect_timeout_seconds=30
curl_max_time_seconds=300

for arch in "${archs[@]}"; do
	target="gitignore-in-${arch}-${version}.tar.gz"
	curl \
		--fail \
		--location \
		--silent \
		--show-error \
		--connect-timeout "${curl_connect_timeout_seconds}" \
		--max-time "${curl_max_time_seconds}" \
		--output "${tmpdir}/${target}" \
		"${release_url}/${target}"
	(cd "${tmpdir}" && shasum -a 256 "${target}") >>"${staging_file}"
done

# Cross-check that every requested arch has exactly one line carrying the
# requested version suffix before we touch any in-repo file. This catches
# truncation, duplicate appends, or accidental version drift in one place.
expected_lines="${#archs[@]}"
actual_lines="$(wc -l <"${staging_file}" | tr -d ' ')"
if [ "${actual_lines}" != "${expected_lines}" ]; then
	echo "expected ${expected_lines} sha256 lines, got ${actual_lines}" >&2
	exit 1
fi
for arch in "${archs[@]}"; do
	target="gitignore-in-${arch}-${version}.tar.gz"
	matches="$(grep -cF "  ${target}" "${staging_file}" || true)"
	if [ "${matches}" != "1" ]; then
		echo "sha256 entry for ${target} appeared ${matches} times (expected 1)" >&2
		exit 1
	fi
done

# Stage the action.yml rewrite next to the new checksum file. We only swap
# both into the repo after they have both been produced successfully.
staging_action="${tmpdir}/action.yml"
sed -E \
	-e "s/version=v[0-9]+\\.[0-9]+\\.[0-9]+$/version=${version}/" \
	"${action_file}" >"${staging_action}"
if ! grep -qF "version=${version}" "${staging_action}"; then
	echo "action.yml version= line did not update to ${version}" >&2
	exit 1
fi

mv "${staging_file}" "${checksum_file}"
mv "${staging_action}" "${action_file}"
