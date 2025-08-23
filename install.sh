#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Dotfiles installer (WSL-safe)
# -----------------------------

echo "🛠️ Installing dotfiles..."

# Helpers
have()   { command -v "$1" >/dev/null 2>&1; }
is_wsl() { grep -qi microsoft /proc/version 2>/dev/null; }

# realpath/readlink -f portability (FreeBSD sometimes lacks -f on readlink)
resolve_path() {
  # Usage: resolve_path <path>
  # Prints an absolute canonical path or echoes the input if resolution fails.
  if have realpath; then
    realpath "$1" 2>/dev/null || printf '%s\n' "$1"
  elif have readlink; then
    readlink -f "$1" 2>/dev/null || printf '%s\n' "$1"
  else
    printf '%s\n' "$1"
  fi
}

# Resolver for symlinks - $PWD
# shellcheck disable=SC2164
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

timestamp() { date +"%Y%m%d-%H%M%S"; }

backup() {
  # Backup existing target if it's a real file/dir (not our identical symlink)
  # $1 = dst, $2 = intended source absolute path
  local dst="$1"
  local intended="$2"

  if [[ -e "$dst" || -L "$dst" ]]; then
    if [[ -L "$dst" ]]; then
      local target
      target="$(resolve_path "$(readlink "$dst" || true)")"
      # If the symlink already points to the intended source, do nothing
      if [[ "$target" == "$intended" ]]; then
        return 0
      fi
    fi
    local bak
    bak="${dst}.bak.$(timestamp)"
    mv -f -- "$dst" "$bak"
    echo "🗂  Backed up $(basename "$dst") → $bak"
  fi
}

link_if_exists() {
  # $1 = source (may be relative or absolute), $2 = dest path
  local src="$1"
  local dst="$2"

  if [[ -e "$src" ]]; then
    mkdir -p -- "$(dirname "$dst")"
    local abs_src
    abs_src="$(resolve_path "$src")"
    backup "$dst" "$abs_src"
    ln -sfn -- "$abs_src" "$dst"
    echo "↪ linked $(basename "$dst") → $abs_src"
  else
    echo "⚠️  skip: $src not found"
  fi
}

heal_bashrc_if_broken() {
  # Replace broken ~/.bashrc symlink with a sane file
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
  # Make sure login shells source ~/.bashrc
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

# --- Detect Operating System ---
OS=""
if (grep -qi "FreeBSD" /etc/os-release 2>/dev/null) || uname | grep -qi "FreeBSD" >/dev/null 2>&1; then
  OS="freebsd"
elif is_wsl; then
  OS="wsl"               # Treat WSL as Linux for shell files; still allow WT tweaks
elif [[ "${OSTYPE:-}" == msys || "${OSTYPE:-}" == cygwin ]]; then
  OS="windows"           # Git Bash / MSYS / Cygwin
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

# --- OS shell files ---
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
    # WSL uses Linux shell files (don’t point at windows/bashrc)
    link_if_exists "$REPO_DIR/linux/bash_profile" "$HOME/.bash_profile"
    link_if_exists "$REPO_DIR/linux/bashrc"       "$HOME/.bashrc"
    link_if_exists "$REPO_DIR/linux/profile"      "$HOME/.profile"
    link_if_exists "$REPO_DIR/linux/shrc"         "$HOME/.shrc"
    ;;
esac

# Fallbacks if something left a broken bashrc
heal_bashrc_if_broken
ensure_bash_profile_sources_bashrc

# --- Optional: distro-aware Fastfetch install (Linux/WSL/FreeBSD) ---
install_fastfetch_maybe() {
  # Controlled via DOTFILES_INSTALL_FASTFETCH=1
  if [[ "${DOTFILES_INSTALL_FASTFETCH:-0}" != "1" ]]; then
    return 0
  fi

  if [[ "$OS" == "linux" || "$OS" == "wsl" ]]; then
    if have pacman; then
      sudo pacman -Sy --needed fastfetch || true
    elif have apt; then
      sudo apt update || true
      sudo apt install -y fastfetch || true
    elif have dnf; then
      sudo dnf install -y fastfetch || true
    elif have apk; then
      sudo apk add fastfetch || true
    elif have zypper; then
      sudo zypper --non-interactive in fastfetch || true
    else
      echo "ℹ️  Skipping Fastfetch (no known package manager found)."
    fi

  elif [[ "$OS" == "freebsd" ]]; then
    if have pkg; then
      sudo pkg install -y fastfetch || true
    else
      echo "ℹ️  Skipping Fastfetch (pkg not found)."
    fi
  fi
}

# --- Optional: fonts/bootstrap helpers ---
# Set DOTFILES_SKIP_FONTS=1 to skip.
run_bootstrap_helpers() {
  if [[ "${DOTFILES_SKIP_FONTS:-0}" == "1" ]]; then
    return 0
  fi

  # Set helpers executable if present
  chmod +x "$REPO_DIR/scripts/bsd-linux.sh" "$REPO_DIR/scripts/windows.sh" 2>/dev/null || true

  # Console fonts, etc. for BSD/Linux/WSL
  if [[ "$OS" == "freebsd" || "$OS" == "linux" || "$OS" == "wsl" ]]; then
    if [[ -x "$REPO_DIR/scripts/bsd-linux.sh" ]]; then
      bash "$REPO_DIR/scripts/bsd-linux.sh" "${BSD_FONT_CONSOLE:-}" || true
    fi
  fi

  # Windows Terminal configs for Windows AND WSL (from Linux using interop or from MSYS/Cygwin)
  if [[ "$OS" == "windows" || "$OS" == "wsl" ]]; then
    if [[ -x "$REPO_DIR/scripts/windows.sh" ]]; then
      bash "$REPO_DIR/scripts/windows.sh" "${WT_FONT:-}" "${WT_SIZE:-}" || true
    fi
  fi
}

# --- WSL niceties ---
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

# Run optional installers/helpers
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
