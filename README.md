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

## Maintenance

To update the bundled `gitignore.in` release manually:

```bash
./scripts/update-version.sh v0.2.0
```

To rehearse the release-preparation workflow without opening a PR, run
`prepare action release update` with `mode=dry-run`.

## License

MIT
