#!/bin/sh
# reset-keyboard-and-shell.sh — reset .shrc, keymap, and KDE keyboard configs

TS=$(date +%s)

echo "🗑️ Backing up configs with timestamp $TS..."

# 1. Shell rc
[ -f "$HOME/.shrc" ] && mv "$HOME/.shrc" "$HOME/.shrc.bak.$TS"

# restore system default shrc
cp /usr/share/skel/dot.shrc "$HOME/.shrc"

# 2. Keyboard map reset
if [ -f /usr/share/syscons/keymaps/us.iso.kbd ]; then
  sudo kbdcontrol -l /usr/share/syscons/keymaps/us.iso.kbd
  echo "🔄 Reset keyboard map to us.iso"
else
  echo "⚠️ Could not find default keymap file"
fi

# 3. KDE Plasma configs
[ -f "$HOME/.config/kglobalshortcutsrc" ] && mv "$HOME/.config/kglobalshortcutsrc" "$HOME/.config/kglobalshortcutsrc.bak.$TS"
[ -f "$HOME/.config/kxkbrc" ] && mv "$HOME/.config/kxkbrc" "$HOME/.config/kxkbrc.bak.$TS"

echo "✅ Reset complete. Restart your session (log out/in) for KDE defaults to reload."
