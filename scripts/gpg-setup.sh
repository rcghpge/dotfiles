#!/usr/bin/env sh
# gpg-setup.sh — Portable GPG signing setup for sh/bash/zsh/tcsh
# Usage:
#   sh gpg-setup.sh [--key KEYID] [--no-global-sign] [--pinentry auto|curses|tty|mac]
# Notes:
#   - Idempotent: backs up ~/.gnupg/gpg.conf and gpg-agent.conf if present
#   - Adds GPG_TTY to: ~/.profile, ~/.bashrc, ~/.zshrc, ~/.cshrc, ~/.tcshrc (if they exist or are created)
#   - Detects pacman/apt/dnf/apk/brew and installs pinentry where possible

set -eu

KEYID=""
SET_GLOBAL_SIGN=1
PINENTRY_MODE="auto"

while [ $# -gt 0 ]; do
  case "$1" in
    --key) KEYID="${2-}"; shift 2 ;;
    --no-global-sign) SET_GLOBAL_SIGN=0; shift 1 ;;
    --pinentry) PINENTRY_MODE="${2-}"; shift 2 ;;
    -h|--help)
      echo "Usage: sh $0 [--key KEYID] [--no-global-sign] [--pinentry auto|curses|tty|mac]"
      exit 0 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

is_cmd() { command -v "$1" >/dev/null 2>&1; }

say()  { printf '%s\n' "$*"; }
ok()   { printf '[OK] %s\n' "$*"; }
info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; }
err()  { printf '[ERR] %s\n' "$*" >&2; }

pkg_install() {
  # $@ = packages
  if is_cmd pacman; then
    sudo pacman -S --needed --noconfirm "$@"
  elif is_cmd apt-get; then
    sudo apt-get update -y
    sudo apt-get install -y "$@"
  elif is_cmd dnf; then
    sudo dnf install -y "$@"
  elif is_cmd apk; then
    sudo apk add --no-cache "$@"
  else
    return 1
  fi
}

ensure_line() {
  # ensure a line exists in a file; creates the file if missing
  _line=$1
  _file=$2
  if [ ! -f "$_file" ]; then
    : >"$_file"
  fi
  if ! grep -Fq "$_line" "$_file" 2>/dev/null; then
    printf '%s\n' "$_line" >>"$_file"
  fi
}

backup_if_exists() {
  _f=$1
  if [ -f "$_f" ]; then
    cp -f "$_f" "$_f.bak.$(date +%Y%m%d%H%M%S)"
    info "Backed up $_f -> $_f.bak.*"
  fi
}

# --- OS detection (for Homebrew/macOS path) ---
OS=$(uname -s || echo "unknown")
case "$OS" in
  Darwin) PLATFORM="macos" ;;
  Linux)  PLATFORM="linux" ;;
  *)      PLATFORM="other" ;;
esac

# --- Ensure gnupg present ---
if ! is_cmd gpg; then
  info "Installing gnupg..."
  if ! pkg_install gnupg; then
    if [ "$PLATFORM" = "macos" ] && is_cmd brew; then
      brew install gnupg
    else
      err "Could not install gnupg automatically. Please install it and re-run."
      exit 1
    fi
  fi
fi
ok "gpg present"

# --- Install pinentry ---
PINENTRY_BIN=""
if [ "$PLATFORM" = "macos" ]; then
  # Prefer GUI pinentry on macOS
  if [ "$PINENTRY_MODE" = "auto" ] || [ "$PINENTRY_MODE" = "mac" ]; then
    if is_cmd brew; then
      brew list --versions pinentry-mac >/dev/null 2>&1 || brew install pinentry-mac
      PINENTRY_BIN=$(command -v pinentry-mac || true)
    else
      warn "Homebrew not found; cannot install pinentry-mac automatically."
    fi
  fi
  if [ -z "${PINENTRY_BIN}" ] && [ "$PINENTRY_MODE" != "mac" ]; then
    if is_cmd brew; then
      brew list --versions pinentry >/dev/null 2>&1 || brew install pinentry
      # try curses
      PINENTRY_BIN=$(command -v pinentry-curses || true)
    fi
  fi
else
  # Linux families
  case "$PINENTRY_MODE" in
    auto|"")
      if is_cmd pacman; then
        pkg_install pinentry || true
        PINENTRY_BIN=$(command -v pinentry-curses || true)
      elif is_cmd apt-get; then
        pkg_install pinentry-curses || pkg_install pinentry || true
        PINENTRY_BIN=$(command -v pinentry-curses || true)
      elif is_cmd dnf; then
        pkg_install pinentry || true
        PINENTRY_BIN=$(command -v pinentry-curses || true)
      elif is_cmd apk; then
        pkg_install pinentry-tty gnupg || pkg_install pinentry gnupg || true
        PINENTRY_BIN=$(command -v pinentry-tty || command -v pinentry-curses || true)
      fi
      ;;
    curses)
      pkg_install pinentry || true
      PINENTRY_BIN=$(command -v pinentry-curses || true)
      ;;
    tty)
      pkg_install pinentry-tty || pkg_install pinentry || true
      PINENTRY_BIN=$(command -v pinentry-tty || true)
      ;;
    mac)
      warn "--pinentry=mac on Linux ignored; using curses"
      pkg_install pinentry || true
      PINENTRY_BIN=$(command -v pinentry-curses || true)
      ;;
  esac
fi

if [ -n "${PINENTRY_BIN}" ]; then
  ok "pinentry found: $PINENTRY_BIN"
else
  warn "No pinentry binary found automatically. You can set it later in gpg-agent.conf."
fi

# --- Write ~/.gnupg configs ---
GNUPGHOME="$HOME/.gnupg"
mkdir -p "$GNUPGHOME"
chmod 700 "$GNUPGHOME"

AGENT_CONF="$GNUPGHOME/gpg-agent.conf"
GPG_CONF="$GNUPGHOME/gpg.conf"

backup_if_exists "$AGENT_CONF"
backup_if_exists "$GPG_CONF"

# gpg-agent.conf
{
  if [ -n "${PINENTRY_BIN}" ]; then
    echo "pinentry-program $PINENTRY_BIN"
  else
    echo "# pinentry-program /path/to/pinentry"
  fi
  echo "allow-loopback-pinentry"
} >"$AGENT_CONF"
chmod 600 "$AGENT_CONF"
ok "wrote $AGENT_CONF"

# gpg.conf
{
  echo "use-agent"
  echo "# Do NOT add 'no-tty' — it breaks interactive prompts."
  echo "pinentry-mode loopback"
} >"$GPG_CONF"
chmod 600 "$GPG_CONF"
ok "wrote $GPG_CONF"

# --- Export GPG_TTY in all common shells ---
# POSIX sh / bash / zsh
ensure_line "export GPG_TTY="$(tty)"" "$HOME/.profile"
ensure_line "export GPG_TTY="$(tty)"" "$HOME/.bashrc"
ensure_line "export GPG_TTY="$(tty)"" "$HOME/.zshrc"

# tcsh / csh
ensure_line "setenv GPG_TTY "`tty`"" "$HOME/.cshrc"
ensure_line "setenv GPG_TTY "`tty`"" "$HOME/.tcshrc"

# Current session
if TTY_NOW=$(tty 2>/dev/null); then
  export GPG_TTY="$TTY_NOW"
fi
ok "GPG_TTY exported and persisted for sh/bash/zsh/tcsh"

# --- Restart agent ---
gpgconf --kill gpg-agent >/dev/null 2>&1 || true
gpgconf --launch gpg-agent >/dev/null 2>&1 || true
ok "gpg-agent restarted"

# --- Configure git ---
# Determine KEYID if not provided
if [ -z "$KEYID" ]; then
  # try git global
  if KEYID=$(git config --global user.signingkey 2>/dev/null || true); then :; fi
fi
if [ -z "$KEYID" ]; then
  # first secret key in keyring
  KEYID=$(gpg --list-secret-keys --with-colons 2>/dev/null | awk -F: '/^sec/ {print $5; exit}')
fi

git config --global gpg.program gpg
git config --global gpg.format openpgp
if [ -n "$KEYID" ]; then
  git config --global user.signingkey "$KEYID"
  ok "git signing key: $KEYID"
else
  warn "No KEYID detected. Set later with: git config --global user.signingkey <YOURKEYID>"
fi
if [ "$SET_GLOBAL_SIGN" -eq 1 ]; then
  git config --global commit.gpgsign true
  ok "git set to sign commits globally"
fi

# --- Summary ---
echo
info "Done. Open a NEW shell or: . ~/.profile   (and re-source your shell rc if needed)."
echo "Test signing:"
echo '  echo ok >> gpg-test.txt && git add gpg-test.txt && git commit -S -m "chore: gpg test"'
echo "Then inspect:"
echo "  git --no-pager log -1 --show-signature"
