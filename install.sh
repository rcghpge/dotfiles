#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Dotfiles installer (WSL-safe)
# -----------------------------

echo "🛠️ Installing dotfiles..."

# Helpers
have()   { command -v "$1" >/dev/null 2>&1; }
is_wsl() { grep -qi microsoft /proc/version 2>/dev/null; }

resolve_path() {
  if have realpath; then
    realpath "$1" 2>/dev/null || printf '%s\n' "$1"
  elif have readlink; then
    readlink -f "$1" 2>/dev/null || printf '%s\n' "$1"
  else
    printf '%s\n' "$1"
  fi
}

# shellcheck disable=SC2164
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
timestamp() { date +"%Y%m%d-%H%M%S"; }

backup() {
  local dst="$1"
  local intended="$2"
  if [[ -e "$dst" || -L "$dst" ]]; then
    if [[ -L "$dst" ]]; then
      local target
      target="$(resolve_path "$(readlink "$dst" || true)")"
      [[ "$target" == "$intended" ]] && return 0
    fi
    local bak; bak="${dst}.bak.$(timestamp)"
    mv -f -- "$dst" "$bak"
    echo "🗂  Backed up $(basename "$dst") → $bak"
  fi
}

link_if_exists() {
  local src="$1" dst="$2"
  if [[ -e "$src" ]]; then
    mkdir -p -- "$(dirname "$dst")"
    local abs_src; abs_src="$(resolve_path "$src")"
    backup "$dst" "$abs_src"
    ln -sfn -- "$abs_src" "$dst"
    echo "↪ linked $(basename "$dst") → $abs_src"
  else
    echo "⚠️  skip: $src not found"
  fi
}

heal_bashrc_if_broken() {
  if [[ -L "$HOME/.bashrc" && ! -e "$HOME/.bashrc" ]]; then
    echo "🩹 Fixing broken ~/.bashrc symlink..."
    rm -f -- "$HOME/.bashrc"
    if [[ -f "$REPO_DIR/linux/bashrc" ]]; then
      cp -f -- "$REPO_DIR/linux/bashrc" "$HOME/.bashrc"
    elif [[ -f /etc/skel/.bashrc ]]; then
      cp -f -- /etc/skel/.bashrc "$HOME/.bashrc"
    else
      : > "$HOME/.bashrc"
    fi
  fi
}

ensure_bash_profile_sources_bashrc() {
  if [[ ! -f "$HOME/.bash_profile" ]]; then
    printf '%s\n' '[ -f ~/.bashrc ] && . ~/.bashrc' > "$HOME/.bash_profile"
    echo "📝 Created ~/.bash_profile to source ~/.bashrc"
  else
    if ! grep -qE '^\[ -f ~/.bashrc \] && \. ~/.bashrc$' "$HOME/.bash_profile" 2>/dev/null; then
      printf '\n[ -f ~/.bashrc ] && . ~/.bashrc\n' >> "$HOME/.bash_profile"
      echo "📝 Updated ~/.bash_profile to source ~/.bashrc"
    fi
  fi
}

# --- Detect OS ---
OS=""
if (grep -qi "FreeBSD" /etc/os-release 2>/dev/null) || uname | grep -qi "FreeBSD" >/dev/null 2>&1; then
  OS="freebsd"
elif is_wsl; then
  OS="wsl"
elif [[ "${OSTYPE:-}" == msys || "${OSTYPE:-}" == cygwin ]]; then
  OS="windows"
elif (grep -qi "linux" /proc/version 2>/dev/null) || [[ "${OSTYPE:-}" == linux-gnu* ]]; then
  OS="linux"
else
  echo "❌ Unsupported OS"
  exit 1
fi
echo "Detected OS: $OS"

# --- Common symlinks ---
link_if_exists "$REPO_DIR/common/aliases"   "$HOME/.aliases"
link_if_exists "$REPO_DIR/common/exports"   "$HOME/.exports"
link_if_exists "$REPO_DIR/common/functions" "$HOME/.functions"

# --- OS-specific ---
case "$OS" in
  windows)
    link_if_exists "$REPO_DIR/windows/bash_profile" "$HOME/.bash_profile"
    link_if_exists "$REPO_DIR/windows/bashrc"       "$HOME/.bashrc"
    link_if_exists "$REPO_DIR/windows/profile"      "$HOME/.profile"
    ;;
  freebsd)
    link_if_exists "$REPO_DIR/freebsd/bash_profile" "$HOME/.bash_profile"
    link_if_exists "$REPO_DIR/freebsd/bashrc"       "$HOME/.bashrc"
    link_if_exists "$REPO_DIR/freebsd/profile"      "$HOME/.profile"
    link_if_exists "$REPO_DIR/freebsd/shrc"         "$HOME/.shrc"
    ;;
  linux|wsl)
    link_if_exists "$REPO_DIR/linux/bash_profile" "$HOME/.bash_profile"
    link_if_exists "$REPO_DIR/linux/bashrc"       "$HOME/.bashrc"
    link_if_exists "$REPO_DIR/linux/profile"      "$HOME/.profile"
    link_if_exists "$REPO_DIR/linux/shrc"         "$HOME/.shrc"
    ;;
esac

heal_bashrc_if_broken
ensure_bash_profile_sources_bashrc

# --- Optional installers/helpers ---
install_fastfetch_maybe() {
  if [[ "${DOTFILES_INSTALL_FASTFETCH:-0}" != "1" ]]; then return 0; fi
  if [[ "$OS" == "linux" || "$OS" == "wsl" ]]; then
    . /etc/os-release 2>/dev/null || true
    case "${ID:-}" in
      arch*|manjaro)   have pacman && sudo pacman -Sy --needed fastfetch || true ;;
      ubuntu|debian*)  have apt && sudo apt update && sudo apt install -y fastfetch || true ;;
      fedora)          have dnf && sudo dnf install -y fastfetch || true ;;
      alpine)          have apk && sudo apk add fastfetch || true ;;
      opensuse*|sles)  have zypper && sudo zypper --non-interactive in fastfetch || true ;;
      *) echo "ℹ️  Skipping Fastfetch (unknown distro: ${ID:-unknown})." ;;
    esac
  elif [[ "$OS" == "freebsd" ]]; then
    have pkg && sudo pkg install -y fastfetch || true
  fi
}
run_bootstrap_helpers() {
  if [[ "${DOTFILES_SKIP_FONTS:-0}" == "1" ]]; then return 0; fi
  chmod +x "$REPO_DIR/scripts/bsd-linux.sh" "$REPO_DIR/scripts/windows.sh" 2>/dev/null || true
  if [[ "$OS" == "freebsd" || "$OS" == "linux" || "$OS" == "wsl" ]]; then
    [[ -x "$REPO_DIR/scripts/bsd-linux.sh" ]] && bash "$REPO_DIR/scripts/bsd-linux.sh" "${BSD_FONT_CONSOLE:-}" || true
  fi
  if [[ "$OS" == "windows" || "$OS" == "wsl" ]]; then
    [[ -x "$REPO_DIR/scripts/windows.sh" ]] && bash "$REPO_DIR/scripts/windows.sh" "${WT_FONT:-}" "${WT_SIZE:-}" || true
  fi
}
wsl_tips() {
  if [[ "$OS" == "wsl" ]]; then
    if [[ ! -f /etc/wsl.conf ]] || ! grep -q '^\[automount\]' /etc/wsl.conf 2>/dev/null; then
      cat <<'WSLTIP'
ℹ️  Tip: for SSH key perms on /mnt/c, consider adding to /etc/wsl.conf:
[automount]
options = "metadata,umask=22,fmask=11"
WSLTIP
    fi
  fi
}

install_fastfetch_maybe
run_bootstrap_helpers
wsl_tips

echo "✅ Done! Restart your shell or run: source ~/.bashrc"

cat <<'EOF'

---------------------------------------
📘 Example usage:

# Default install
./install.sh

# Install and also fetch Fastfetch
DOTFILES_INSTALL_FASTFETCH=1 ./install.sh

# Skip font/bootstrap scripts
DOTFILES_SKIP_FONTS=1 ./install.sh

# Override Windows Terminal font & size (when on Windows/WSL)
WT_FONT='Terminus (TTF)' WT_SIZE=12 ./install.sh

# BSD/Linux console font override
BSD_FONT_CONSOLE='iso15-8x16' ./install.sh
---------------------------------------
EOF
