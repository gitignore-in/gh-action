# GitHub Action for gitignore-in

gitignore-in is a tool to generate .gitignore files from templates.
This action runs gitignore-in and creates a pull request if the `.gitignore` file has changed.

## Example

.gitignore.in is a template file for gitignore-in. And this works as ordinary shell script.

```bash
gibo dump macOS
gibo dump Windows
echo "node_modules/"
```

> **Note:** `gibo dump Windows` above is a `.gitignore` template example — it fetches Windows-specific ignore patterns for the generated `.gitignore` file. It is unrelated to the runner platform this action runs on.

```
$ gitignore-in
Generated .gitignore
```

If the .gitignore.in is changed, the action will create pull request automatically.

## Usage

```yaml
permissions:
  contents: write       # needed to push the updated .gitignore to the PR branch
  pull-requests: write  # needed to open and update the pull request
steps:
- uses: actions/checkout@v4
- uses: gitignore-in/gh-action@main
```

> **Note:** Repositories whose default token permissions are set to read-only (common in organizations) must declare `contents: write` and `pull-requests: write` explicitly. The action uses `github.token` to create the pull request via `peter-evans/create-pull-request`, so without these permissions the PR step will fail silently.

For production use, pin to a specific tag or SHA to avoid unexpected changes:

```yaml
permissions:
  contents: write
  pull-requests: write
steps:
- uses: actions/checkout@v4
- uses: gitignore-in/gh-action@v0.2.3  # or pin to a full SHA
```

## Supported platforms

| Runner OS | Architecture | Supported |
|---|---|---|
| Linux | x64 (X64) | Yes |
| Linux | ARM64 | Yes |
| macOS | x64 (X64) | Yes |
| macOS | ARM64 | Yes |
| Windows | any | No |

Windows and other platforms are not supported. The action exits with an error if run on an unsupported runner.

## Inputs

| Input | Description | Default |
|---|---|---|
| `branch_name` | Branch name for the pull request | `gitignore-in` |
| `base_branch` | Base branch for the pull request | `main` |
| `commit_message` | Commit message for the `.gitignore` update | `Update .gitignore by gitignore.in` |
| `pr_title` | Pull request title | `Update .gitignore` |
| `pr_body` | Pull request body | `Update .gitignore by gitignore.in` |
| `delete_branch` | Delete the branch after merge | `true` |
| `boilerplates_ref` | Git ref (branch, tag, or SHA) of the [toptal/gitignore](https://github.com/toptal/gitignore) boilerplates database to pin. When set, every run produces identical `.gitignore` output for the same `.gitignore.in` template. Leave empty to always use the latest boilerplates (default, non-deterministic). | `""` |
| `gitignore-version` | Version of the `gitignore-in` binary to download (e.g. `v0.2.1`). When set to the bundled default, the binary is verified against `bundled-binary.sha256`. For any other version, SHA-256 verification is skipped; intended for testing pre-release binaries only. | `v0.2.1` |

> **Note on input naming:** The existing inputs above (`branch_name`, `base_branch`, etc.) use
> `snake_case` for historical reasons. The newer `gitignore-version` input uses `kebab-case` to
> align with the outputs convention. A future major release will standardise all inputs to
> `kebab-case`; until then, the table above shows the exact key names to use in `with:`.

### Pinning the boilerplates database

By default the action fetches the latest boilerplates database on every run.
To produce reproducible `.gitignore` output, pass a specific commit SHA:

```yaml
- uses: gitignore-in/gh-action@main
  with:
    boilerplates_ref: "abc1234"  # SHA from github.com/toptal/gitignore
```

## Outputs

| Output | Description |
|---|---|
| `pull-request-number` | Pull request number (empty when no PR was created or updated) |
| `pull-request-url` | Pull request URL |
| `pull-request-operation` | Operation performed: `created`, `updated`, or `closed` |
| `pull-request-head-sha` | SHA of the head commit of the pull request |
| `boilerplates-ref` | Commit SHA of the boilerplates database used; empty string if unavailable |

Example — notify on new PR:

```yaml
- uses: gitignore-in/gh-action@main
  id: gitignore
- if: steps.gitignore.outputs.pull-request-operation == 'created'
  run: echo "New PR ${{ steps.gitignore.outputs.pull-request-url }}"
```

## Maintenance

The action downloads the bundled `gitignore.in` release version declared in
`action.yml`, and verifies each platform artifact with `bundled-binary.sha256`.

When `gitignore-in/gitignore-in` publishes a new release, the
`prepare action release update` workflow can prepare the version bump pull
request. To update the bundled release manually instead, run:

```bash
./scripts/update-version.sh v0.2.1
```

To rehearse the release-preparation workflow without opening a PR, run
`prepare action release update` with `mode=dry-run`.
The workflow accepts `vMAJOR.MINOR.PATCH` release tags and verifies the
corresponding `gitignore-in/gitignore-in` release before updating `action.yml`
and `bundled-binary.sha256`.

See [Operational state machines](docs/state-machines.md) for the pull request,
draft release, release update, and workflow concurrency boundaries that govern
this action.

## License

MIT
