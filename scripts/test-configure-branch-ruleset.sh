#!/bin/sh
# Test ruleset lookup edge cases without calling the GitHub API.

set -eu

tmpdir=$(mktemp -d)
trap 'rm -rf "${tmpdir}"' EXIT

cat >"${tmpdir}/gh" <<'SCRIPT'
#!/bin/sh
case "${GH_MOCK_RULESETS:-single}" in
single)
	printf '%s\n' 123
	;;
none)
	:
	;;
duplicate)
	printf '%s\n' 123 456
	;;
*)
	echo "unexpected GH_MOCK_RULESETS=${GH_MOCK_RULESETS}" >&2
	exit 2
	;;
esac
SCRIPT
chmod +x "${tmpdir}/gh"

output=$(PATH="${tmpdir}:${PATH}" GH_MOCK_RULESETS=single scripts/configure-branch-ruleset.sh --dry-run)
printf '%s\n' "${output}" | grep 'Dry run: would add required_status_checks to ruleset 123'

set +e
output=$(PATH="${tmpdir}:${PATH}" GH_MOCK_RULESETS=none scripts/configure-branch-ruleset.sh --dry-run 2>&1)
status=$?
set -e
[ "${status}" -eq 1 ]
printf '%s\n' "${output}" | grep "Error: ruleset 'default-branch-baseline' not found"

set +e
output=$(PATH="${tmpdir}:${PATH}" GH_MOCK_RULESETS=duplicate scripts/configure-branch-ruleset.sh --dry-run 2>&1)
status=$?
set -e
[ "${status}" -eq 1 ]
printf '%s\n' "${output}" | grep "Error: expected exactly one ruleset named 'default-branch-baseline', found 2"
printf '%s\n' "${output}" | grep '123'
printf '%s\n' "${output}" | grep '456'
