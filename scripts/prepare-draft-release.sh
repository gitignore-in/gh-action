#!/usr/bin/env bash
set -euo pipefail

command_name="${1:-}"

resolve_version() {
	local version="${INPUT_VERSION:-}"
	if [ -z "${version}" ]; then
		local response_with_headers
		local status
		set +e
		response_with_headers="$(gh api --include "repos/${GITHUB_REPOSITORY}/releases/latest")"
		status=$?
		set -e

		if [ "${status}" -ne 0 ]; then
			local http_status
			http_status="$(printf '%s\n' "${response_with_headers}" | head -1 | tr -d '\r' | awk '{print $2}')"
			if [ "${http_status}" = "404" ]; then
				echo "no latest release found; provide a version via workflow_dispatch input" >&2
				return 1
			fi
			printf '%s\n' "${response_with_headers}" >&2
			return "${status}"
		fi

		local latest
		latest="$(printf '%s\n' "${response_with_headers}" | awk 'found { print } /^[[:space:]]*$/ { found = 1 }' | jq -r '.tag_name')"
		if [ -z "${latest}" ] || [ "${latest}" = "null" ]; then
			echo "latest release response did not contain a tag name" >&2
			return 1
		fi
		if ! [[ "${latest}" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
			echo "latest release tag does not match vMAJOR.MINOR.PATCH: ${latest}" >&2
			return 1
		fi
		version="v${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.$((BASH_REMATCH[3] + 1))"
	fi

	if ! [[ "${version}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		echo "version must use vMAJOR.MINOR.PATCH format: ${version}" >&2
		return 1
	fi
	printf '%s\n' "${version}"
}

assert_release_is_writable() {
	local version="${VERSION:?VERSION must be set}"
	local response_with_headers
	local status
	set +e
	response_with_headers="$(gh api --include "repos/${GITHUB_REPOSITORY}/releases/tags/${version}")"
	status=$?
	set -e

	if [ "${status}" -ne 0 ]; then
		local http_status
		http_status="$(printf '%s' "${response_with_headers}" | head -1 | tr -d '\r' | awk '{print $2}')"
		if [ "${http_status}" = "404" ]; then
			return 0
		fi
		printf '%s\n' "${response_with_headers}" >&2
		return "${status}"
	fi

	local release_json
	release_json="$(printf '%s' "${response_with_headers}" | sed '1,/^$/d')"
	local is_draft
	is_draft="$(printf '%s' "${release_json}" | jq -r '.draft')"
	if [ "${is_draft}" = "true" ]; then
		return 0
	fi
	echo "release ${version} already exists and is published; choose a new version" >&2
	return 1
}

case "${command_name}" in
resolve-version)
	resolve_version
	;;
assert-release-is-writable)
	assert_release_is_writable
	;;
*)
	echo "usage: $0 {resolve-version|assert-release-is-writable}" >&2
	exit 2
	;;
esac
