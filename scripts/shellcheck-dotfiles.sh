#!/usr/bin/env bash
# This Bash script runs shellcheck for shell linting on all shell scripts in your dotfiles directory.

set -euo pipefail

# Path to your dotfiles directory
DOTFILES_DIR="$HOME/dotfiles"

# Check if shellcheck is installed
if ! command -v shellcheck &>/dev/null; then
  echo "Error: shellcheck is not installed. You can install it with:"
  echo "  sudo apt install shellcheck       # Debian/Ubuntu"
  echo "  brew install shellcheck           # macOS"
  echo "  sudo dnf install ShellCheck       # Fedora"
  exit 1
fi

echo "🔍 Linting shell scripts in $DOTFILES_DIR..."

find "$DOTFILES_DIR" \
  -type f \( -name "*.sh" -o -executable \) \
  ! -path "*/.git/*" \
  ! -name "*.zip" \
  ! -name "*.tar" \
  ! -name "*.gz" \
  -exec file --mime-type {} + \
  | grep -E 'text/x-shellscript|text/plain' \
  | cut -d: -f1 \
  | while read -r file; do
    echo "▶ $file"
    shellcheck "$file"
done

printf "\n✅ Dotfiles lint check complete.\n"

