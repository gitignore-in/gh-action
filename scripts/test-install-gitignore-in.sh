#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
installer="${script_dir}/install-gitignore-in.sh"

make_fixture() {
	local fixture_dir
	fixture_dir="$(mktemp -d)"
	mkdir -p "${fixture_dir}/bin" "${fixture_dir}/logs" "${fixture_dir}/runner-temp"
	touch "${fixture_dir}/github-path"

	cat >"${fixture_dir}/bin/wget" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "wget $*" >> "${STUB_LOG_DIR}/wget.log"
url="${!#}"
target="${url##*/}"
: > "${target}"
EOF

	cat >"${fixture_dir}/bin/tar" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "tar $*" >> "${STUB_LOG_DIR}/tar.log"
: > gitignore.in
EOF

	cat >"${fixture_dir}/bin/shasum" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "shasum $*" >> "${STUB_LOG_DIR}/shasum.log"
EOF

	chmod +x "${fixture_dir}/bin/wget" "${fixture_dir}/bin/tar" "${fixture_dir}/bin/shasum"
	printf '%s\n' "${fixture_dir}"
}

run_installer() {
	local fixture_dir="$1"
	local version="$2"
	local allow_unverified="${3:-}"

	if [ -n "${allow_unverified}" ]; then
		env \
			PATH="${fixture_dir}/bin:${PATH}" \
			STUB_LOG_DIR="${fixture_dir}/logs" \
			RUNNER_OS=Linux \
			RUNNER_ARCH=X64 \
			RUNNER_TEMP="${fixture_dir}/runner-temp" \
			GITHUB_PATH="${fixture_dir}/github-path" \
			GITIGNORE_IN_VERSION="${version}" \
			GITIGNORE_IN_ALLOW_UNVERIFIED_VERSION="${allow_unverified}" \
			"${installer}"
	else
		env \
			PATH="${fixture_dir}/bin:${PATH}" \
			STUB_LOG_DIR="${fixture_dir}/logs" \
			RUNNER_OS=Linux \
			RUNNER_ARCH=X64 \
			RUNNER_TEMP="${fixture_dir}/runner-temp" \
			GITHUB_PATH="${fixture_dir}/github-path" \
			GITIGNORE_IN_VERSION="${version}" \
			"${installer}"
	fi
}

assert_file_contains() {
	local file="$1"
	local expected="$2"
	if ! grep -F -- "${expected}" "${file}" >/dev/null; then
		echo "expected '${expected}' in ${file}" >&2
		cat "${file}" >&2 || true
		exit 1
	fi
}

test_bundled_version_verifies_sha256() {
	local fixture_dir output status
	fixture_dir="$(make_fixture)"

	set +e
	output="$(
		run_installer "${fixture_dir}" "v0.2.1" 2>&1
	)"
	status=$?
	set -e

	if [ "${status}" -ne 0 ]; then
		echo "${output}" >&2
		exit 1
	fi

	assert_file_contains "${fixture_dir}/logs/shasum.log" "shasum -a 256 -c"
	assert_file_contains "${fixture_dir}/github-path" "${fixture_dir}/runner-temp/gitignore-in/bin"
	[ -x "${fixture_dir}/runner-temp/gitignore-in/bin/gitignore.in" ]
}

test_custom_version_requires_explicit_opt_in() {
	local fixture_dir output status
	fixture_dir="$(make_fixture)"

	set +e
	output="$(
		run_installer "${fixture_dir}" "v9.9.9" 2>&1
	)"
	status=$?
	set -e

	if [ "${status}" -eq 0 ]; then
		echo "expected custom version without opt-in to fail" >&2
		exit 1
	fi
	if [ "${status}" -ne 1 ]; then
		echo "expected exit 1, got ${status}" >&2
		echo "${output}" >&2
		exit 1
	fi
	if ! grep -F -- "allow-unverified-gitignore-version=true" <<<"${output}" >/dev/null; then
		echo "expected explicit opt-in message" >&2
		echo "${output}" >&2
		exit 1
	fi
	if [ -f "${fixture_dir}/logs/wget.log" ]; then
		echo "expected no download attempt without opt-in" >&2
		cat "${fixture_dir}/logs/wget.log" >&2
		exit 1
	fi
}

test_version_rejects_newline_before_logging() {
	local fixture_dir malicious_version output status
	fixture_dir="$(make_fixture)"
	malicious_version=$'v9.9.9\n::error::forged'

	set +e
	output="$(
		run_installer "${fixture_dir}" "${malicious_version}" "true" 2>&1
	)"
	status=$?
	set -e

	if [ "${status}" -eq 0 ]; then
		echo "expected newline-containing version to fail" >&2
		exit 1
	fi
	if [ "${status}" -ne 1 ]; then
		echo "expected exit 1, got ${status}" >&2
		echo "${output}" >&2
		exit 1
	fi
	if ! grep -F -- "gitignore-version must not contain newline characters" <<<"${output}" >/dev/null; then
		echo "expected newline rejection message" >&2
		echo "${output}" >&2
		exit 1
	fi
	if grep -F -- "::error::forged" <<<"${output}" >/dev/null; then
		echo "expected malicious version content to stay out of logs" >&2
		echo "${output}" >&2
		exit 1
	fi
	if [ -f "${fixture_dir}/logs/wget.log" ]; then
		echo "expected no download attempt for newline-containing version" >&2
		cat "${fixture_dir}/logs/wget.log" >&2
		exit 1
	fi
}

test_custom_version_with_opt_in_skips_sha256() {
	local fixture_dir output status
	fixture_dir="$(make_fixture)"

	set +e
	output="$(
		run_installer "${fixture_dir}" "v9.9.9" "true" 2>&1
	)"
	status=$?
	set -e

	if [ "${status}" -ne 0 ]; then
		echo "${output}" >&2
		exit 1
	fi

	assert_file_contains "${fixture_dir}/logs/wget.log" "gitignore-in-x86_64-unknown-linux-gnu-v9.9.9.tar.gz"
	if [ -f "${fixture_dir}/logs/shasum.log" ]; then
		echo "expected custom version with opt-in to skip checksum verification" >&2
		cat "${fixture_dir}/logs/shasum.log" >&2
		exit 1
	fi
	assert_file_contains "${fixture_dir}/github-path" "${fixture_dir}/runner-temp/gitignore-in/bin"
	[ -x "${fixture_dir}/runner-temp/gitignore-in/bin/gitignore.in" ]
	if ! grep -F -- "SHA-256 verification skipped" <<<"${output}" >/dev/null; then
		echo "expected warning about skipped verification" >&2
		echo "${output}" >&2
		exit 1
	fi
}

test_bundled_version_verifies_sha256
test_custom_version_requires_explicit_opt_in
test_version_rejects_newline_before_logging
test_custom_version_with_opt_in_skips_sha256
