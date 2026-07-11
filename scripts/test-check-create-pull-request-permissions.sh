#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
helper="${script_dir}/check-create-pull-request-permissions.sh"

make_fixture() {
	local fixture_dir
	fixture_dir="$(mktemp -d)"
	mkdir -p "${fixture_dir}/bin"

	cat >"${fixture_dir}/bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "${STUB_PERMISSION_JSON:-}"
EOF

	chmod +x "${fixture_dir}/bin/curl"
	printf '%s\n' "${fixture_dir}"
}

run_helper() {
	local fixture_dir="$1"
	local permission_json="$2"
	env \
		PATH="${fixture_dir}/bin:${PATH}" \
		GITHUB_REPOSITORY="gitignore-in/gh-action" \
		GITHUB_TOKEN="test-token" \
		GITHUB_API_URL="https://api.github.com" \
		STUB_PERMISSION_JSON="${permission_json}" \
		"${helper}"
}

assert_failure_contains() {
	local expected="$1"
	local output="$2"
	if ! grep -F -- "${expected}" <<<"${output}" >/dev/null; then
		echo "expected output to contain: ${expected}" >&2
		echo "${output}" >&2
		exit 1
	fi
}

test_allows_write_permissions() {
	local fixture_dir output status
	fixture_dir="$(make_fixture)"

	set +e
	output="$(
		run_helper "${fixture_dir}" '{"permissions":{"push":true,"pull":true}}' 2>&1
	)"
	status=$?
	set -e

	if [ "${status}" -ne 0 ]; then
		echo "${output}" >&2
		exit 1
	fi
}

test_rejects_missing_write_permissions() {
	local fixture_dir output status
	fixture_dir="$(make_fixture)"

	set +e
	output="$(
		run_helper "${fixture_dir}" '{"permissions":{"push":true,"pull":false}}' 2>&1
	)"
	status=$?
	set -e

	if [ "${status}" -eq 0 ]; then
		echo "expected missing permissions to fail" >&2
		exit 1
	fi
	assert_failure_contains "permissions.push=true permissions.pull=false" "${output}"
	assert_failure_contains "contents: write" "${output}"
	assert_failure_contains "pull-requests: write" "${output}"
}

test_requires_token() {
	local fixture_dir output status
	fixture_dir="$(make_fixture)"

	set +e
	output="$(
		env \
			PATH="${fixture_dir}/bin:${PATH}" \
			GITHUB_REPOSITORY="gitignore-in/gh-action" \
			GITHUB_API_URL="https://api.github.com" \
			"${helper}" 2>&1
	)"
	status=$?
	set -e

	if [ "${status}" -eq 0 ]; then
		echo "expected missing token to fail" >&2
		exit 1
	fi
	assert_failure_contains "GITHUB_TOKEN is required" "${output}"
}

test_allows_write_permissions
test_rejects_missing_write_permissions
test_requires_token
