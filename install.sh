#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Dotfiles installer (WSL-safe)
# -----------------------------

echo "🛠️ Installing dotfiles..."

# Helpers
have()   { command -v "$1" >/dev/null 2>&1; }
is_wsl() { grep -qi microsoft /proc/version 2>/dev/null; }

# Resolve repo root so symlinks don't depend on $PWD
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

timestamp() { date +"%Y%m%d-%H%M%S"; }

backup() {
  # Backup existing target if it's a real file/dir (not our identical symlink)
  local dst="$1"
  if [[ -e "$dst" || -L "$dst" ]]; then
    if [[ -L "$dst" ]]; then
      local target
      target="$(readlink -f "$dst" || true)"
      [[ "$target" == "$2" ]] && return 0
    fi
    local bak="${dst}.bak.$(timestamp)"
    mv -f "$dst" "$bak"
    echo "🗂  Backed up $(basename "$dst") → $bak"
  fi
}

link_if_exists() {
  local src="$1" dst="$2"
  if [[ -e "$src" ]]; then
    mkdir -p "$(dirname "$dst")"
    backup "$dst" "$(readlink -f "$src")"
    ln -sfn "$src" "$dst"
    echo "↪ linked $(basename "$dst") → $src"
  else
    echo "⚠️  skip: $src not found"
  fi
}

heal_bashrc_if_broken() {
  # Replace broken ~/.bashrc symlink with a sane file
  if [[ -L "$HOME/.bashrc" && ! -e "$HOME/.bashrc" ]]; then
    echo "🩹 Fixing broken ~/.bashrc symlink..."
    rm -f "$HOME/.bashrc"
    if [[ -f "$REPO_DIR/linux/bashrc" ]]; then
      cp -f "$REPO_DIR/linux/bashrc" "$HOME/.bashrc"
    elif [[ -f /etc/skel/.bashrc ]]; then
      cp -f /etc/skel/.bashrc "$HOME/.bashrc"
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
    grep -q '[ -f ~/.bashrc ] && \. ~/.bashrc' "$HOME/.bash_profile" 2>/dev/null || \
      printf '\n[ -f ~/.bashrc ] && . ~/.bashrc\n' >> "$HOME/.bash_profile"
  fi
}

# --- Detect Operating System ---
OS=""
if (grep -qi "FreeBSD" /etc/os-release 2>/dev/null) || uname | grep -qi "FreeBSD"; then
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

# --- OS-specific shell files ---
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

# Self-heal if something left a broken bashrc
heal_bashrc_if_broken
ensure_bash_profile_sources_bashrc

# --- Optional: fonts/bootstrap helpers ---
# Set DOTFILES_SKIP_FONTS=1 to skip.
if [[ "${DOTFILES_SKIP_FONTS:-0}" != "1" ]]; then
  chmod +x "$REPO_DIR/scripts/bsd-linux.sh" "$REPO_DIR/scripts/windows.sh" 2>/dev/null || true

  # Console fonts, etc. for BSD/Linux/WSL
  if [[ "$OS" == "freebsd" || "$OS" == "linux" || "$OS" == "wsl" ]]; then
    bash "$REPO_DIR/scripts/bsd-linux.sh" "${BSD_FONT_CONSOLE:-}" || true
  fi

  # Windows Terminal tweaks for Windows AND WSL (from Linux using interop or from MSYS)
  if [[ "$OS" == "windows" || "$OS" == "wsl" ]]; then
    bash "$REPO_DIR/scripts/windows.sh" "${WT_FONT:-}" "${WT_SIZE:-}" || true
  fi
fi

# --- WSL niceties (non-fatal) ---
if [[ "$OS" == "wsl" ]]; then
  if [[ ! -f /etc/wsl.conf ]] || ! grep -q '^\[automount\]' /etc/wsl.conf 2>/dev/null; then
    echo "ℹ️  Tip: for SSH key perms on /mnt/c, consider adding to /etc/wsl.conf:"
    echo "[automount]"
    echo 'options = "metadata,umask=22,fmask=11"'
  fi
fi

echo "✅ Done! Restart your shell or run: source ~/.bashrc"
