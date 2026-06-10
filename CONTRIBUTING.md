# Contributing

Thank you for your interest in contributing to gitignore-in/gh-action.

## Reporting Issues

Use [GitHub Issues](https://github.com/gitignore-in/gh-action/issues) to report bugs or suggest improvements.

When reporting a bug, include:

- What you expected to happen
- What actually happened
- The workflow YAML (or a minimal reproduction)
- Runner OS and architecture
- The action version you are using (`@main`, a tag, or a pinned SHA)

For security vulnerabilities, open a [private security advisory](https://github.com/gitignore-in/gh-action/security/advisories/new) instead of a public issue.

## Submitting Changes

1. Fork the repository and create a topic branch from `main`.
2. Keep changes focused — one logical change per pull request.
3. Run the CI checks locally if possible; the `main.yml` workflow runs on pull requests.
4. Open a pull request against `main` with a clear description of what changed and why.

## Commit Messages

Follow the format `prefix: short description` using one of:

- `fix:` — bug fix
- `feat:` — new capability
- `docs:` — documentation only
- `chore:` — maintenance (dependency bumps, script updates)
- `ci:` — CI workflow changes

## Reference Policy: `@main` vs Tags

See [docs/RELEASE.md](docs/RELEASE.md#reference-policy-main-vs-tags) for guidance on which ref to use.

## License

By contributing, you agree that your changes will be released under the [MIT License](LICENSE).
