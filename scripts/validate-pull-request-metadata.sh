#!/usr/bin/env bash
set -euo pipefail

validate_single_line() {
	local name="$1"
	local value="$2"
	local max_length="$3"

	if [ -z "${value}" ]; then
		echo "${name} must not be empty" >&2
		exit 1
	fi
	if ((${#value} > max_length)); then
		echo "${name} must be ${max_length} characters or fewer" >&2
		exit 1
	fi
	case "${value}" in
	*$'\n'* | *$'\r'*)
		echo "${name} must be single-line text" >&2
		exit 1
		;;
	esac
	if printf '%s' "${value}" | LC_ALL=C grep -q $'[\001-\037\177]'; then
		echo "${name} must not contain ASCII control characters" >&2
		exit 1
	fi
}

validate_body() {
	local name="$1"
	local value="$2"
	local max_length="$3"

	if ((${#value} > max_length)); then
		echo "${name} must be ${max_length} characters or fewer" >&2
		exit 1
	fi
	if printf '%s' "${value}" | LC_ALL=C grep -q $'[\001-\010\013\014\016-\037\177]'; then
		echo "${name} must not contain ASCII control characters other than tab, line feed, or carriage return" >&2
		exit 1
	fi
}

validate_single_line "commit_message" "${GITIGNORE_IN_COMMIT_MESSAGE:-}" 200
validate_single_line "pr_title" "${GITIGNORE_IN_PR_TITLE:-}" 200
validate_body "pr_body" "${GITIGNORE_IN_PR_BODY:-}" 60000
