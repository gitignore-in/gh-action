# Operational state machines

This repository has several small state machines around pull requests,
release drafts, release update preparation, and workflow concurrency. This
document defines their boundaries so maintenance work does not rely on
implicit behavior from third-party actions.

## Download verification

The composite action downloads the `gitignore.in` binary before generating a
consumer `.gitignore`. The requested `gitignore-version` selects the release
artifact, and `allow-unverified-gitignore-version` separately decides whether a
non-bundled version may skip repository-owned checksum verification.

States:

- `verified-download`: the requested `gitignore-version` matches the bundled
  version recorded in `action.yml`. The installer must verify the downloaded
  archive against `bundled-binary.sha256` before extracting it.
- `blocked-unverified-download`: the requested `gitignore-version` differs from
  the bundled version and `allow-unverified-gitignore-version` is not `true`.
  The installer must stop before downloading an archive whose checksum is not
  tracked in this repository.
- `unverified-download`: the requested `gitignore-version` differs from the
  bundled version and `allow-unverified-gitignore-version=true`. The installer
  may download and extract the archive, but it must emit a warning because no
  repository-owned SHA-256 entry is available for that custom version.

Boundary:

- `scripts/install-gitignore-in.sh` owns this state machine.
- `action.yml` is the single source of truth for the bundled version. The
  installer reads the `gitignore-version` default from that metadata instead of
  hard-coding the bundled version a second time.
- `bundled-binary.sha256` is authoritative only for the bundled version.
  Custom versions are intentionally treated as unverified unless the caller
  opts in with `allow-unverified-gitignore-version=true`.
- The unverified path is for pre-release or compatibility testing. Regular
  consumers should use the default bundled version so downloads remain
  checksum-verified.

Recovery:

- If a normal workflow reaches `blocked-unverified-download`, remove the custom
  `gitignore-version` input or update it to the bundled version.
- If a maintainer intentionally tests a custom version, set
  `allow-unverified-gitignore-version=true` and treat the warning as an
  explicit trust decision for that run.
- If a release update changes the bundled version, update `action.yml` and
  `bundled-binary.sha256` together so `verified-download` keeps matching the
  checksum file.

## Consumer `.gitignore` pull request

The composite action checks out the consumer repository, runs `gitignore.in`,
and then runs `scripts/has-meaningful-gitignore-diff.sh` against `.gitignore`.

States:

- `no-meaningful-diff`: `.gitignore` has no content change that should be
  published. The pull request step is skipped.
- `meaningful-diff`: `.gitignore` has a content change. The pull request step
  may create or update the configured branch and pull request.
- `pull-request-created`: `peter-evans/create-pull-request` created a pull
  request and exposes `pull-request-operation=created`.
- `pull-request-updated`: the action updated an existing pull request and
  exposes `pull-request-operation=updated`.
- `pull-request-closed`: the action closed an existing pull request and
  exposes `pull-request-operation=closed`.

Boundary:

- `scripts/has-meaningful-gitignore-diff.sh` is the only repository-owned
  gate between `no-meaningful-diff` and `meaningful-diff`.
- When the gate reports `changed=false`, this action does not call
  `peter-evans/create-pull-request`; it also does not inspect or close any
  pre-existing consumer pull request.
- Consumers that manually change the same generated `.gitignore` branch should
  close obsolete pull requests themselves, or run the action again after a
  meaningful generated diff exists.

## Draft release preparation

The `prepare draft release` workflow resolves the next action release version
and asks `softprops/action-gh-release` to create or update a draft.

States:

- `no-release`: no GitHub release exists for the resolved version. The workflow
  may create a new draft release.
- `draft-release`: a draft release already exists. The workflow may update that
  draft.
- `published-release`: a published release already exists. The workflow must
  stop instead of rewriting it.

Boundary:

- The workflow must check the resolved release before calling
  `softprops/action-gh-release`.
- A published release is immutable for this workflow. To change a published
  release, publish a newer version instead of reusing the same tag.

Responsibility:

- A maintainer reviews the auto-generated draft release notes and clicks
  **Publish release** in the GitHub Releases UI when the notes are accurate
  and the release is ready.
- No workflow publishes a release automatically; the publish step is always a
  human decision.
- If a draft accumulates without being published, a maintainer should either
  publish it, delete it, or update `action.yml` to reflect the intended next
  version.

See [RELEASE.md](RELEASE.md) for release cadence guidance.

Recovery:

- If the workflow stops on `published-release`, rerun it with a new
  `vMAJOR.MINOR.PATCH` version.
- If a draft is wrong, delete or edit the draft before publishing it.

## Bundled binary release update

The `prepare action release update` workflow resolves a released
`gitignore-in/gitignore-in` version, validates the release artifact, and then
opens a repository pull request.

States:

- `resolved`: the input release version and mode are valid.
- `validated`: the upstream release exists and the bundled binary smoke test
  passed.
- `dry-run-complete`: validation passed and `mode=dry-run`, so no pull request
  is opened.
- `pull-request-opened`: validation passed and `mode=prepare-pr`, so the
  update branch and pull request are created or updated.
- `prepare-failed`: validation passed, but the update or pull request step
  failed.

Boundary:

- `validate` and `prepare-update` both run `scripts/update-version.sh`; they
  intentionally re-check the release artifact in separate jobs.
- `prepare-update` is only allowed after `validate` succeeds.
- A `prepare-failed` run should be retried from the workflow entrypoint so the
  upstream release is validated again.

Recovery:

- For transient network or GitHub API failures, rerun the workflow with the
  same version and mode.
- For a bad upstream release artifact, wait for a corrected upstream release
  or choose a newer version.

## Workflow concurrency

Each workflow uses a `concurrency` group that includes the workflow name, event
name, and pull request number or ref.

States:

- `single-active-run`: no newer run with the same concurrency group exists.
- `cancelled-by-newer-run`: a newer run for the same group starts and cancels
  the older run.

Boundary:

- Runs from different workflows or different refs may proceed independently.
- Runs for the same workflow and ref should not update the same branch in
  parallel.

Recovery:

- If a run is cancelled by a newer run, inspect the newer run rather than
  rerunning the cancelled one.
