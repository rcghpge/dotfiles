#!/usr/bin/env bash
set -euo pipefail

echo "🛠️ Installing dotfiles..."

have()   { command -v "$1" >/dev/null 2>&1; }
is_wsl() { grep -qi microsoft /proc/version 2>/dev/null; }

# --- Detect Operating System ---
OS=""
if grep -qi "FreeBSD" /etc/os-release 2>/dev/null || uname | grep -qi "FreeBSD"; then
  OS="freebsd"
elif [[ "${OSTYPE:-}" == "msys" || "${OSTYPE:-}" == "cygwin" ]]; then
  OS="windows"
elif is_wsl; then
  OS="windows"     # treat WSL as Windows host for Windows Terminal config
elif grep -qi "linux" /proc/version 2>/dev/null || [[ "${OSTYPE:-}" == "linux-gnu"* ]]; then
  OS="linux"
else
  echo "❌ Unsupported OS"
  exit 1
fi

echo "Detected OS: $OS"

# --- Symlinks ---
ln -sf "$PWD/common/aliases"   ~/.aliases
ln -sf "$PWD/common/exports"   ~/.exports
ln -sf "$PWD/common/functions" ~/.functions

case "$OS" in
  windows)
    ln -sf "$PWD/windows/bash_profile" ~/.bash_profile
    ln -sf "$PWD/windows/bashrc"       ~/.bashrc
    ln -sf "$PWD/windows/profile"      ~/.profile
    ;;
  freebsd)
    ln -sf "$PWD/freebsd/bash_profile" ~/.bash_profile
    ln -sf "$PWD/freebsd/bashrc"       ~/.bashrc
    ln -sf "$PWD/freebsd/profile"      ~/.profile
    ln -sf "$PWD/freebsd/shrc"         ~/.shrc
    ;;
  linux)
    ln -sf "$PWD/linux/bash_profile" ~/.bash_profile
    ln -sf "$PWD/linux/bashrc"       ~/.bashrc
    ln -sf "$PWD/linux/profile"      ~/.profile
    ln -sf "$PWD/linux/shrc"         ~/.shrc
    ;;
esac

# --- Optional: fonts/bootstrap helpers ---
# Set DOTFILES_SKIP_FONTS=1 to skip.
if [[ "${DOTFILES_SKIP_FONTS:-0}" != "1" ]]; then
  chmod +x "$PWD/scripts"/{bsd-linux.sh,windows.sh} 2>/dev/null || true

  if [[ "$OS" == "freebsd" ]]; then
    # FreeBSD console font (defaults inside bsd-linux.sh)
    bash "$PWD/scripts/bsd-linux.sh" ${BSD_FONT_CONSOLE:-} || true
  elif [[ "$OS" == "linux" ]]; then
    # Native Linux console font (Arch/Debian/Ubuntu handled in bsd-linux.sh)
    bash "$PWD/scripts/bsd-linux.sh" ${BSD_FONT_CONSOLE:-} || true
  fi

  # If running under WSL or MSYS/Cygwin, also set Windows Terminal font
  if is_wsl || [[ "${OSTYPE:-}" == "msys" || "${OSTYPE:-}" == "cygwin" ]]; then
    # Pass optional env overrides WT_FONT / WT_SIZE
    bash "$PWD/scripts/windows.sh" "${WT_FONT:-}" "${WT_SIZE:-}" || true
  fi
fi

echo "✅ Done! Restart your shell or run: source ~/.bashrc"

