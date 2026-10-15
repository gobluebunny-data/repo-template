#!/usr/bin/env bash
#
# setup-macos.sh
#
# Installs the local toolchain used by every repository in this organisation.
# Idempotent: re-running upgrades what is installed and skips the rest.
#
#   Homebrew, git, GitHub CLI, jq
#   uv with Python 3.12, ruff, pre-commit
#   Azure CLI, Databricks CLI, Terraform
#   Docker Desktop, Visual Studio Code with the Databricks and Python extensions
#   Claude Code
#
# Usage:
#   ./setup-macos.sh [-n "Git author name"] [-e git-author-email]
#
# Requires macOS 13 or later and an administrator account; Homebrew asks for
# the account password once. A first run takes 10 to 20 minutes, mostly
# downloads. Docker Desktop must be opened once afterwards to accept its terms.

set -euo pipefail

GIT_NAME=""
GIT_EMAIL=""
usage() { echo "usage: $(basename "$0") [-n NAME] [-e EMAIL]" >&2; exit "${1:-0}"; }
while getopts ":n:e:h" opt; do
  case "$opt" in
    n) GIT_NAME="$OPTARG" ;;
    e) GIT_EMAIL="$OPTARG" ;;
    h) usage 0 ;;
    *) usage 1 ;;
  esac
done

log() { printf '\n==> %s\n' "$*"; }
[[ "$(uname -s)" == "Darwin" ]] || { echo "This script is for macOS." >&2; exit 1; }

# --- Homebrew ---------------------------------------------------------------
log "Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -x /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    else
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi
fi
BREW_PREFIX="$(brew --prefix)"
PROFILE="$HOME/.zprofile"
[[ "${SHELL##*/}" == "bash" ]] && PROFILE="$HOME/.bash_profile"
if ! grep -qs 'brew shellenv' "$PROFILE"; then
  printf '\neval "$(%s/bin/brew shellenv)"\n' "$BREW_PREFIX" >> "$PROFILE"
fi
# Skip Homebrew's post-install cleanup: it is slow and a stray unwritable file
# in the prefix makes it fail, which must not abort this script.
export HOMEBREW_NO_INSTALL_CLEANUP=1 HOMEBREW_NO_ENV_HINTS=1
brew update >/dev/null

# --- Command-line tools -----------------------------------------------------
log "Command-line tools"
# A failure in one package is reported, not fatal; the version table at the end shows gaps.
brew_install() { brew install "$@" || echo "    WARN: brew install $* exited non-zero; see the version table below"; }
brew_install git gh jq uv azure-cli
# Homebrew requires third-party taps to be trusted explicitly before use.
brew tap databricks/tap >/dev/null
brew trust --formula databricks/tap/databricks >/dev/null 2>&1 || true
brew_install databricks/tap/databricks
brew tap hashicorp/tap >/dev/null
brew trust --formula hashicorp/tap/terraform >/dev/null 2>&1 || true
brew_install hashicorp/tap/terraform

# --- Applications -----------------------------------------------------------
# A cask install fails if the app was installed by hand, so check first.
cask() {
  local token="$1" check="$2"
  if [[ -e "$check" ]] || brew list --cask "$token" >/dev/null 2>&1; then
    echo "    present: $token"
  else
    brew install --cask "$token"
  fi
}
log "Applications"
cask docker-desktop "/Applications/Docker.app" \
  || echo "    WARN: Docker Desktop did not install (unsupported macOS version?); fallback: brew install colima docker"
cask visual-studio-code "/Applications/Visual Studio Code.app" \
  || echo "    WARN: Visual Studio Code did not install"
if command -v claude >/dev/null 2>&1; then echo "    present: claude-code"; else brew_install --cask claude-code; fi

# --- Python, ruff, pre-commit -----------------------------------------------
log "Python 3.12, ruff, pre-commit"
uv python install 3.12
uv tool install --upgrade ruff
uv tool install --upgrade pre-commit
uv tool update-shell >/dev/null 2>&1 || true
export PATH="$HOME/.local/bin:$PATH"

# --- VS Code extensions -----------------------------------------------------
log "VS Code extensions"
CODE="$(command -v code 2>/dev/null || echo "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code")"
"$CODE" --install-extension databricks.databricks --force >/dev/null
"$CODE" --install-extension ms-python.python --force >/dev/null
echo "    installed: databricks.databricks, ms-python.python"

# --- git identity -----------------------------------------------------------
log "git configuration"
[[ -n "$GIT_NAME" ]]  && git config --global user.name "$GIT_NAME"
[[ -n "$GIT_EMAIL" ]] && git config --global user.email "$GIT_EMAIL"
git config --global init.defaultBranch main
echo "    user.name:  $(git config --global user.name || echo '(not set)')"
echo "    user.email: $(git config --global user.email || echo '(not set)')"

# --- Versions ---------------------------------------------------------------
log "Installed versions"
show() { printf '    %-12s %s\n' "$1" "$2"; }
show git        "$(git --version)"
show gh         "$(gh --version | head -n1)"
show jq         "$(jq --version)"
show uv         "$(uv --version)"
show python     "$("$(uv python find 3.12)" --version)"
show ruff       "$(ruff --version)"
show pre-commit "$(pre-commit --version)"
show az         "$(az version --query '"azure-cli"' -o tsv)"
show databricks "$(databricks --version)"
show terraform  "$(terraform version | head -n1)"
show docker     "$(docker --version 2>/dev/null || echo 'installed; open Docker Desktop once to finish setup')"
show code       "$("$CODE" --version | head -n1)"
show claude     "$(claude --version 2>/dev/null || echo 'installed; open a new terminal')"

printf '\nNext, once each:\n'
printf '  gh auth login --web -h github.com -p https -s repo,workflow,project,read:org\n'
printf '  az login\n'
printf '  open -a Docker        # accept the terms on first launch\n'
printf '\nOpen a new terminal window so PATH changes take effect.\n'
