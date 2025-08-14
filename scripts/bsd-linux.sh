#!/usr/bin/env bash
# Set a crisp console font with FreeBSD font.
# FreeBSD VT: uses terminus-b32 by default
# Arch Linux: uses ter-v32n
# Debian/Ubuntu: configures console-setup to Terminus 16x32
set -euo pipefail

FONT_CONSOLE="${1:-terminus-b32}"   # FreeBSD VT font name (see /usr/share/vt/fonts)
ARCH_VCONSOLE="${2:-ter-v32n}"
UBU_FACE="${3:-Terminus}"
UBU_SIZE="${4:-16x32}"

say() { printf "\033[1;32m==>\033[0m %s\n" "$*"; }
err() { printf "\033[1;31mERR:\033[0m %s\n" "$*" >&2; }

if command -v sysrc >/dev/null 2>&1; then
  # ---------- FreeBSD ----------
  say "Detected FreeBSD"
  if ! pkg info -e terminus-font >/dev/null 2>&1; then
    say "Installing terminus-font"
    sudo pkg install -y terminus-font
  fi

  if [ -e "/usr/share/vt/fonts/${FONT_CONSOLE}.fnt" ] || [ -e "/usr/share/vt/fonts/${FONT_CONSOLE}" ]; then
    say "Applying VT font now: ${FONT_CONSOLE}"
    sudo vidcontrol -f "${FONT_CONSOLE}" || true
    say "Persisting via rc.conf"
    sudo sysrc allscreens_flags="-f ${FONT_CONSOLE}"
  else
    err "Font ${FONT_CONSOLE} not found in /usr/share/vt/fonts"
    ls -1 /usr/share/vt/fonts || true
    exit 1
  fi

  # Optional: TTF for GUI terminals
  pkg info -e terminus-ttf >/dev/null 2>&1 || sudo pkg install -y terminus-ttf || true
  exit 0
fi

# ---------- Linux ----------
if [ -f /etc/arch-release ]; then
  say "Detected Arch Linux"
  sudo pacman -S --noconfirm --needed terminus-font
  echo "FONT=${ARCH_VCONSOLE}" | sudo tee /etc/vconsole.conf >/dev/null
  say "Set console font to ${ARCH_VCONSOLE}. Reboot or run: sudo setfont ${ARCH_VCONSOLE}"
  # Optional TTFs (for GUI terminals)
  sudo pacman -S --noconfirm --needed ttf-terminus-nerd || true
  exit 0
fi

if command -v apt-get >/dev/null 2>&1; then
  say "Detected Debian/Ubuntu"
  sudo apt-get update -y
  sudo apt-get install -y console-setup fonts-terminus
  sudo sed -i "s/^FONTFACE=.*/FONTFACE=\"${UBU_FACE}\"/"  /etc/default/console-setup
  sudo sed -i "s/^FONTSIZE=.*/FONTSIZE=\"${UBU_SIZE}\"/" /etc/default/console-setup
  say "Configured console-setup. Apply with: sudo dpkg-reconfigure console-setup   (or reboot)"
  exit 0
fi

err "Unsupported OS. Nothing changed."
exit 2

