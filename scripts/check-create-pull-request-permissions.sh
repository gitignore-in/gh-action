#!/usr/bin/env bash
set -euo pipefail

repo="${GITHUB_REPOSITORY:-}"
api_url="${GITHUB_API_URL:-https://api.github.com}"
token="${GITHUB_TOKEN:-}"

if [ -z "${repo}" ]; then
	echo "usage: GITHUB_REPOSITORY=<owner>/<repo> GITHUB_TOKEN=<token> $0" >&2
	exit 2
fi

if [ -z "${token}" ]; then
	echo "::error::GITHUB_TOKEN is required to preflight repository write permissions before creating a pull request." >&2
	exit 1
fi

repo_json="$(
	curl -fsSL \
		-H "Authorization: Bearer ${token}" \
		-H "Accept: application/vnd.github+json" \
		-H "X-GitHub-Api-Version: 2022-11-28" \
		"${api_url}/repos/${repo}"
)"

permissions="$(
	printf '%s' "${repo_json}" | ruby -e '
		require "json"
		data = JSON.parse(STDIN.read)
		perms = data.fetch("permissions", {})
		puts [perms["push"], perms["pull"]].map { |value| value ? "true" : "false" }.join(" ")
	'
)"

read -r push_permission pull_permission <<<"${permissions}"
push_permission="${push_permission:-false}"
pull_permission="${pull_permission:-false}"

if [ "${push_permission}" != "true" ] || [ "${pull_permission}" != "true" ]; then
	echo "::error::This action needs repository write access for both contents and pull requests. GitHub reported permissions.push=${push_permission} permissions.pull=${pull_permission}; add permissions: contents: write and pull-requests: write to the consumer workflow." >&2
	exit 1
fi
