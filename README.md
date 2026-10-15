# repo-template

Repository template: Python with uv, ruff, pytest, pre-commit and CI

## Local setup (macOS)

The toolchain is installed by `scripts/setup-macos.sh`, which is idempotent:

```bash
./scripts/setup-macos.sh -n "Your Name" -e you@example.com
```

It installs Homebrew, git, the GitHub CLI, jq, uv with Python 3.12, ruff, pre-commit, the Azure CLI, the Databricks CLI, Terraform, Docker Desktop, Visual Studio Code with the Databricks and Python extensions, and Claude Code, then prints the installed versions.

## Working in this repository

```bash
uv sync                               # create .venv and install the dev dependencies
uv run pre-commit install             # run the hooks on every commit
uv run pre-commit run --all-files     # lint and format everything
uv run pytest                         # run the tests
```

CI runs the same checks on every pull request and on every push to `main`. `main` is protected: changes arrive by pull request with a green `ci` check, and the branch history is linear.

## Layout

```
.github/workflows/ci.yml   lint, format and tests on every PR and push to main
docs/decisions/            decision log: one entry per decision
scripts/                   setup and maintenance scripts
tests/                     pytest suite
```
