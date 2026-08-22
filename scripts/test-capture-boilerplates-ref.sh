#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"
helper="${repo_root}/scripts/capture-boilerplates-ref.sh"

test_captures_head_sha_from_git_repo() {
	local tmpdir
	tmpdir="$(mktemp -d)"
	(
		trap 'rm -rf "${tmpdir}"' EXIT
		mkdir -p "${tmpdir}/boilerplates"
		git -C "${tmpdir}/boilerplates" init --quiet
		git -C "${tmpdir}/boilerplates" config user.name test
		git -C "${tmpdir}/boilerplates" config user.email test@example.com
		printf 'placeholder\n' >"${tmpdir}/boilerplates/placeholder.gitignore"
		git -C "${tmpdir}/boilerplates" add placeholder.gitignore
		git -C "${tmpdir}/boilerplates" commit --quiet -m init
		local sha
		sha="$(git -C "${tmpdir}/boilerplates" rev-parse --verify HEAD)"

		GITHUB_OUTPUT="${tmpdir}/output.txt" "${helper}" "${tmpdir}/boilerplates"
		if ! grep -qx "boilerplates-ref=${sha}" "${tmpdir}/output.txt"; then
			echo "expected boilerplates-ref=${sha}" >&2
			cat "${tmpdir}/output.txt" >&2
			exit 1
		fi
	)
}

test_empty_ref_when_directory_is_not_a_git_repo() {
	local tmpdir
	tmpdir="$(mktemp -d)"
	(
		trap 'rm -rf "${tmpdir}"' EXIT
		mkdir -p "${tmpdir}/boilerplates"

		GITHUB_OUTPUT="${tmpdir}/output.txt" "${helper}" "${tmpdir}/boilerplates"
		if ! grep -qx "boilerplates-ref=" "${tmpdir}/output.txt"; then
			echo "expected empty boilerplates-ref for a non-git directory" >&2
			cat "${tmpdir}/output.txt" >&2
			exit 1
		fi
	)
}

test_empty_ref_when_directory_is_missing() {
	local tmpdir
	tmpdir="$(mktemp -d)"
	(
		trap 'rm -rf "${tmpdir}"' EXIT

		GITHUB_OUTPUT="${tmpdir}/output.txt" "${helper}" "${tmpdir}/does-not-exist"
		if ! grep -qx "boilerplates-ref=" "${tmpdir}/output.txt"; then
			echo "expected empty boilerplates-ref for a missing directory" >&2
			cat "${tmpdir}/output.txt" >&2
			exit 1
		fi
	)
}

test_captures_head_sha_from_git_repo
test_empty_ref_when_directory_is_not_a_git_repo
test_empty_ref_when_directory_is_missing
