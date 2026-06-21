#!/usr/bin/env bash
set -euo pipefail

version="${GITIGNORE_IN_VERSION:-${1:-}}"
allow_unverified="${GITIGNORE_IN_ALLOW_UNVERIFIED_VERSION:-${2:-}}"
if [ -z "${version}" ]; then
	echo "usage: $0 <version>" >&2
	exit 2
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
action_file="${repo_root}/action.yml"

# Read the bundled version from action.yml so the installer stays in sync with
# the release metadata without duplicating the default in two places.
bundled_version="$(
	awk '
		$1 == "gitignore-version:" { in_section = 1; next }
		in_section && $1 == "default:" {
			gsub(/"/, "", $2)
			print $2
			exit
		}
	' "${action_file}"
)"
if [ -z "${bundled_version}" ]; then
	echo "failed to determine bundled gitignore-version from ${action_file}" >&2
	exit 1
fi

if [ "${version}" != "${bundled_version}" ] && [ "${allow_unverified}" != "true" ]; then
	echo "::error::Custom gitignore-version '${version}' requires allow-unverified-gitignore-version=true; SHA-256 verification is disabled without explicit opt-in." >&2
	exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT
cd "${tmpdir}"

case "${RUNNER_OS}-${RUNNER_ARCH}" in
Linux-X64)
	target="gitignore-in-x86_64-unknown-linux-gnu-${version}.tar.gz"
	;;
Linux-ARM64)
	target="gitignore-in-aarch64-unknown-linux-gnu-${version}.tar.gz"
	;;
macOS-X64)
	target="gitignore-in-x86_64-apple-darwin-${version}.tar.gz"
	;;
macOS-ARM64)
	target="gitignore-in-aarch64-apple-darwin-${version}.tar.gz"
	;;
*)
	echo "Unsupported runner platform: ${RUNNER_OS}-${RUNNER_ARCH}" >&2
	exit 1
	;;
esac

url="https://github.com/gitignore-in/gitignore-in/releases/download/${version}/${target}"
echo "Downloading ${url} (${RUNNER_OS}-${RUNNER_ARCH})" >&2
wget --tries=3 --timeout=60 "${url}"

if [ "${version}" = "${bundled_version}" ]; then
	grep -F "  ${target}" "${repo_root}/bundled-binary.sha256" >"${target}.sha256"
	shasum -a 256 -c "${target}.sha256"
else
	echo "::warning::Custom gitignore-version '${version}' used; SHA-256 verification skipped because allow-unverified-gitignore-version=true. Only use for testing pre-release binaries." >&2
fi

tar -xzf "${target}"
mkdir -p "${RUNNER_TEMP}/gitignore-in/bin"
install -m 0755 gitignore.in "${tmpdir}/gitignore.in.installed"
mv "${tmpdir}/gitignore.in.installed" "${RUNNER_TEMP}/gitignore-in/bin/gitignore.in"
echo "${RUNNER_TEMP}/gitignore-in/bin" >>"${GITHUB_PATH}"
