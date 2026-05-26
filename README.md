# GitHub Action for gitignore-in

gitignore-in is a tool to generate .gitignore files from templates.
This action runs gitignore-in and commits the result to the repository.

## Example

.gitignore.in is a template file for gitignore-in. And this works as ordinary shell script.

```bash
gibo dump macOS
gibo dump Windows
echo "node_modules/"
```

```
$ gitignore-in
Generated .gitignore
```

If the .gitignore.in is changed, the action will create pull request automatically.

## Usage

```yaml
steps:
- uses: actions/checkout@v4
- uses: gitignore-in/gh-action@main
```

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

### Pinning the boilerplates database

By default the action fetches the latest boilerplates database on every run.
To produce reproducible `.gitignore` output, pass a specific commit SHA:

```yaml
- uses: gitignore-in/gh-action@main
  with:
    boilerplates_ref: "abc1234"  # SHA from github.com/toptal/gitignore
```

## Maintenance

To update the bundled `gitignore.in` release manually:

```bash
./scripts/update-version.sh v0.2.0
```

To rehearse the release-preparation workflow without opening a PR, run
`prepare action release update` with `mode=dry-run`.
The workflow accepts `vMAJOR.MINOR.PATCH` release tags and verifies the
corresponding `gitignore-in/gitignore-in` release before updating `action.yml`.

See [Operational state machines](docs/state-machines.md) for the pull request,
draft release, release update, and workflow concurrency boundaries that govern
this action.

## License

MIT
