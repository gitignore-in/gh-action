#!/bin/sh
# Test ruleset lookup edge cases without calling the GitHub API.

set -eu

tmpdir=$(mktemp -d)
trap 'rm -rf "${tmpdir}"' EXIT

cat >"${tmpdir}/gh" <<'SCRIPT'
#!/bin/sh
# Find the API path (first repos/... argument after `api`).
path=""
for arg in "$@"; do
	case "${arg}" in
	repos/*)
		if [ -z "${path}" ]; then path="${arg}"; fi
		;;
	esac
done
case "${path}" in
*/rulesets)
	# Ruleset list: returned as a JSON array, matching the GitHub API shape.
	case "${GH_MOCK_RULESETS:-single}" in
	single)
		printf '%s\n' '[{"name":"default-branch-baseline","id":123}]'
		;;
	none)
		printf '%s\n' '[]'
		;;
	duplicate)
		printf '%s\n' '[{"name":"default-branch-baseline","id":123},{"name":"default-branch-baseline","id":456}]'
		;;
	*)
		echo "unexpected GH_MOCK_RULESETS=${GH_MOCK_RULESETS}" >&2
		exit 2
		;;
	esac
	;;
*/rulesets/*)
	# Ruleset detail: existing required_status_checks differs from desired,
	# so the script reports that an update is needed.
	printf '%s\n' '{"rules":[{"type":"required_status_checks","parameters":{"required_status_checks":[]}}]}'
	;;
esac
SCRIPT
chmod +x "${tmpdir}/gh"

output=$(PATH="${tmpdir}:${PATH}" GH_MOCK_RULESETS=single scripts/configure-branch-ruleset.sh --dry-run 2>&1)
printf '%s\n' "${output}" | grep 'Dry run: would update required_status_checks in ruleset 123'
printf '%s\n' "${output}" | grep '"context":"version-coherence"'

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
