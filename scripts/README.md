# scripts/

This directory contains shell scripts serving different purposes.

## Action runtime

These scripts are called from `action.yml` and run inside **end-users' CI environments**
as part of the action. Renaming or moving them is a breaking change.

| Script | Purpose |
| --- | --- |
| `has-meaningful-gitignore-diff.sh` | Determines whether a `.gitignore` diff contains meaningful changes (ignoring comment-only lines) |
| `run-with-timeout.sh` | Runs a command with a timeout, forwarding signals for clean shutdown |

## Development tooling

These scripts run only in **this repository's own CI** or on maintainer machines.
They are not part of the action's public interface.

| Script | Purpose |
| --- | --- |
| `check-required-status-checks.sh` | Verifies that required status checks are configured on the branch ruleset |
| `check-version-sha256-coherence.sh` | Checks that the bundled binary version matches its SHA-256 checksum |
| `configure-branch-ruleset.sh` | Applies the required-status-checks ruleset to the default branch (requires admin token) |
| `update-version.sh` | Updates the bundled `gitignore.in` version string in `action.yml` (release tooling) |

## Tests

| Script | Purpose |
| --- | --- |
| `test-configure-branch-ruleset.sh` | Tests for `configure-branch-ruleset.sh` |
| `test-has-meaningful-gitignore-diff.sh` | Tests for `has-meaningful-gitignore-diff.sh` |
| `test-run-with-timeout.sh` | Tests for `run-with-timeout.sh` |
| `test-run-with-timeout-signals.sh` | Signal handling tests for `run-with-timeout.sh` |
| `test-update-version-usage.sh` | Tests for `update-version.sh` |

## Adding a new script

- If the script must run as part of the action in users' CI: add it to the **Action runtime** table above and update `action.yml`.
- If the script is only for this repo's CI or maintenance: add it to the **Development tooling** table above.
- Use the `test-<script-name>.sh` naming convention for test scripts.
