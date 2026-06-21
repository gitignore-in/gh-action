# Release Governance

This document describes how releases of the `gitignore-in/gh-action` action are governed,
who is responsible for each step, and how automated workflows relate to human decisions.

## Release lifecycle

```
action.yml merged to main
        ↓
prepare-draft-release workflow creates a draft GitHub release
        ↓
Maintainer reviews the draft release notes
        ↓
Maintainer publishes the draft release (manual step)
        ↓
Tag is live; consumers pinned to that tag receive the new version
```

### Publish decision (human step)

After `prepare-draft-release` runs, a draft release accumulates automatically-generated
release notes. A maintainer reviews the draft and clicks **Publish** in the GitHub
Releases UI when the notes are accurate and the release is ready.

There is no bot or workflow that publishes the release automatically.
If a draft has been sitting for several days without publishing, the maintainer should
either publish it, delete the draft, or update `action.yml` to reflect the intended
next version.

## Bundled binary update

When `gitignore-in/gitignore-in` publishes a new release, the `prepare action release update`
workflow can be triggered automatically via `repository_dispatch` from upstream,
or manually via workflow dispatch.

### Upstream dispatch payload schema

The workflow listens for `repository_dispatch` events of type `gitignore-in-release-published`.
The `client_payload` must conform to the following schema:

| Field | Type | Required | Valid values | Default |
|---|---|---|---|---|
| `version` | string | **required** | `vMAJOR.MINOR.PATCH` format (e.g. `v0.3.0`) | — |
| `mode` | string | optional | `prepare-pr`, `dry-run` | `prepare-pr` |

**`version`** must match the pattern `^v[0-9]+\.[0-9]+\.[0-9]+$`; the workflow exits with
an error if the pattern does not match or the field is absent.

**`mode`** controls workflow behaviour:
- `prepare-pr` (default): validate the release and open an update pull request.
- `dry-run`: validate the release only; skip pull request creation.

If `mode` is omitted the workflow silently defaults to `prepare-pr`.
Passing any value other than the two above causes the workflow to exit with an error.

Example dispatch invocation via `gh`:

```sh
gh api repos/gitignore-in/gh-action/dispatches \
  --method POST \
  --field event_type=gitignore-in-release-published \
  --field 'client_payload[version]=v0.3.0' \
  --field 'client_payload[mode]=dry-run'
```

### Human responsibility

The `prepare action release update` workflow opens a pull request. A maintainer must:

1. Review the PR (version bump in `action.yml`, updated `bundled-binary.sha256`).
2. Merge the PR after the CI checks pass.
3. Verify that the bundled binary smoke test passed in the workflow run.

If the upstream dispatch never arrives (upstream wiring not configured), trigger the
workflow manually via the GitHub Actions UI or `gh workflow run`.

### Cadence

There is no hard cadence requirement. As a guideline, bundle updates should be merged
within two weeks of a new upstream release. The
[audit-bundled-binary-version-stale-001](https://github.com/kitsuyui/kimono-tasks)
finding tracks version drift.

## Reference policy: `@main` vs tags

| Reference | When to use |
|---|---|
| `@main` | Development or testing — always picks up the latest bundled binary and workflow changes. May include breaking changes without notice. |
| `@vMAJOR.MINOR.PATCH` | Production use — pinned to a known-good release. Recommended for stability. |
| SHA pinning | Highest reproducibility — immune to tag rewrites. Use for security-sensitive workflows. |

Semantic versioning intent:
- **patch** (`v0.x.PATCH`): bug fixes, binary updates, documentation changes
- **minor** (`v0.MINOR.0`): new inputs or outputs added in a backwards-compatible way
- **major** (`vMAJOR.0.0`): breaking changes to inputs, outputs, or behavior

Until v1.0.0, minor-version bumps may include behaviour changes; pin to the full
`vMAJOR.MINOR.PATCH` tag for the most stable experience.

## State machine boundaries

See [state-machines.md](state-machines.md) for the detailed state machine definitions
for consumer pull requests, draft release preparation, bundled binary update, and
workflow concurrency.
