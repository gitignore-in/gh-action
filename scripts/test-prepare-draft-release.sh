#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="${script_dir}/prepare-draft-release.sh"

expect_output() {
	local description="$1"
	local expected="$2"
	shift 2

	local output
	output="$("$@")"
	if [ "${output}" != "${expected}" ]; then
		echo "${description}: expected '${expected}', got '${output}'" >&2
		exit 1
	fi
}

expect_failure() {
	local description="$1"
	local expected="$2"
	shift 2

	local output
	local status
	set +e
	output="$("$@" 2>&1)"
	status=$?
	set -e
	if [ "${status}" -eq 0 ]; then
		echo "${description}: expected failure" >&2
		exit 1
	fi
	if ! grep -F -- "${expected}" <<<"${output}" >/dev/null; then
		echo "${description}: expected diagnostic containing '${expected}'" >&2
		printf '%s\n' "${output}" >&2
		exit 1
	fi
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT
mkdir -p "${tmpdir}/bin"
cat >"${tmpdir}/bin/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s' "${GH_RESPONSE}"
exit "${GH_STATUS:-0}"
EOF
chmod +x "${tmpdir}/bin/gh"

test_resolve_explicit_version() {
	expect_output \
		"explicit version" \
		"v4.5.6" \
		env INPUT_VERSION=v4.5.6 "${script}" resolve-version
}

test_resolve_next_version_from_latest_release() {
	expect_output \
		"latest release version" \
		"v1.2.4" \
		env \
		PATH="${tmpdir}/bin:${PATH}" \
		GITHUB_REPOSITORY=example/action \
		GH_RESPONSE=$'HTTP/2 200\n\n{"tag_name":"v1.2.3"}' \
		"${script}" resolve-version
}

test_resolve_missing_latest_release() {
	expect_failure \
		"missing latest release" \
		"no latest release found" \
		env \
		PATH="${tmpdir}/bin:${PATH}" \
		GITHUB_REPOSITORY=example/action \
		GH_STATUS=1 \
		GH_RESPONSE=$'HTTP/2 404\n\n{"message":"Not Found"}' \
		"${script}" resolve-version
}

test_rejects_invalid_latest_release() {
	expect_failure \
		"invalid latest release" \
		"latest release tag does not match vMAJOR.MINOR.PATCH" \
		env \
		PATH="${tmpdir}/bin:${PATH}" \
		GITHUB_REPOSITORY=example/action \
		GH_RESPONSE=$'HTTP/2 200\n\n{"tag_name":"release-1"}' \
		"${script}" resolve-version
}

test_rejects_non_404_latest_release_error() {
	expect_failure \
		"non-404 latest release error" \
		"HTTP/2 500" \
		env \
		PATH="${tmpdir}/bin:${PATH}" \
		GITHUB_REPOSITORY=example/action \
		GH_STATUS=1 \
		GH_RESPONSE=$'HTTP/2 500\n\n{"message":"Server Error"}' \
		"${script}" resolve-version
}

test_resolve_invalid_version() {
	expect_failure \
		"invalid explicit version" \
		"version must use vMAJOR.MINOR.PATCH format" \
		env INPUT_VERSION=not-a-version "${script}" resolve-version
}

test_allows_absent_release() {
	env \
		PATH="${tmpdir}/bin:${PATH}" \
		GITHUB_REPOSITORY=example/action \
		VERSION=v1.2.3 \
		GH_STATUS=1 \
		GH_RESPONSE=$'HTTP/2 404\n\n{"message":"Not Found"}' \
		"${script}" assert-release-is-writable
}

test_allows_existing_draft() {
	env \
		PATH="${tmpdir}/bin:${PATH}" \
		GITHUB_REPOSITORY=example/action \
		VERSION=v1.2.3 \
		GH_RESPONSE=$'HTTP/2 200\n\n{"draft":true}' \
		"${script}" assert-release-is-writable
}

test_rejects_published_release() {
	expect_failure \
		"published release" \
		"release v1.2.3 already exists and is published" \
		env \
		PATH="${tmpdir}/bin:${PATH}" \
		GITHUB_REPOSITORY=example/action \
		VERSION=v1.2.3 \
		GH_RESPONSE=$'HTTP/2 200\n\n{"draft":false}' \
		"${script}" assert-release-is-writable
}

test_rejects_non_404_api_error() {
	expect_failure \
		"non-404 GitHub API error" \
		"HTTP/2 500" \
		env \
		PATH="${tmpdir}/bin:${PATH}" \
		GITHUB_REPOSITORY=example/action \
		VERSION=v1.2.3 \
		GH_STATUS=1 \
		GH_RESPONSE=$'HTTP/2 500\n\n{"message":"Server Error"}' \
		"${script}" assert-release-is-writable
}

test_resolve_explicit_version
test_resolve_next_version_from_latest_release
test_resolve_missing_latest_release
test_rejects_invalid_latest_release
test_rejects_non_404_latest_release_error
test_resolve_invalid_version
test_allows_absent_release
test_allows_existing_draft
test_rejects_published_release
test_rejects_non_404_api_error
