#!/usr/bin/env bash
set -euo pipefail

script="scripts/update-version.sh"

expect_usage_error() {
	local description="$1"
	local expected="$2"
	shift 2

	local output
	local status
	set +e
	output="$("$@" 2>&1 >/dev/null)"
	status=$?
	set -e

	if [ "${status}" -ne 2 ]; then
		echo "${description}: expected exit 2, got ${status}" >&2
		printf '%s\n' "${output}" >&2
		exit 1
	fi
	if ! grep -F -- "${expected}" <<<"${output}" >/dev/null; then
		echo "${description}: expected diagnostic containing '${expected}'" >&2
		printf '%s\n' "${output}" >&2
		exit 1
	fi
}

expect_usage_error "missing version" "usage:" env -u GITIGNORE_IN_VERSION "$script"
expect_usage_error "invalid argument version" "version must use vMAJOR.MINOR.PATCH format: not-a-version" "$script" not-a-version
expect_usage_error "invalid environment version" "version must use vMAJOR.MINOR.PATCH format: not-a-version" env GITIGNORE_IN_VERSION=not-a-version "$script"

test_updates_action_default_with_stubbed_download() {
	local tmpdir
	tmpdir="$(mktemp -d)"
	(
		trap 'rm -rf "${tmpdir}"' EXIT
		mkdir -p "${tmpdir}/bin" "${tmpdir}/scripts"
		cp action.yml bundled-binary.sha256 "${tmpdir}/"
		cp scripts/update-version.sh scripts/read-bundled-gitignore-version.sh "${tmpdir}/scripts/"
		chmod +x "${tmpdir}/scripts/"*.sh

		cat >"${tmpdir}/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output=""
while [ "$#" -gt 0 ]; do
	case "$1" in
	--output)
		output="$2"
		shift 2
		;;
	*)
		shift
		;;
	esac
done
if [ -z "${output}" ]; then
	echo "missing --output" >&2
	exit 2
fi
: >"${output}"
EOF
		cat >"${tmpdir}/bin/shasum" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
target="${!#}"
printf '0000000000000000000000000000000000000000000000000000000000000000  %s\n' "${target}"
EOF
		chmod +x "${tmpdir}/bin/curl" "${tmpdir}/bin/shasum"

		PATH="${tmpdir}/bin:${PATH}" "${tmpdir}/scripts/update-version.sh" v9.8.7

		actual="$("${tmpdir}/scripts/read-bundled-gitignore-version.sh" "${tmpdir}/action.yml")"
		if [ "${actual}" != "v9.8.7" ]; then
			echo "expected action default to update to v9.8.7, got ${actual}" >&2
			exit 1
		fi
		if [ "$(grep -cF v9.8.7 "${tmpdir}/bundled-binary.sha256")" -ne 4 ]; then
			echo "expected all checksum entries to use v9.8.7" >&2
			cat "${tmpdir}/bundled-binary.sha256" >&2
			exit 1
		fi
	)
}

test_updates_action_default_with_stubbed_download
