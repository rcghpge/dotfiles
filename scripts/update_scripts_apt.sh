#!/usr/bin/env bash
# ⚙️ Safely patch all dotfiles scripts to use apt-get instead of apt, with backups

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
ROOT_DIR="$(realpath "$SCRIPT_DIR/..")"
BACKUP_EXT=".bak"

# Warn user
echo "⚠️  This will modify all *.sh scripts in $ROOT_DIR to replace 'apt' with 'apt-get'."
echo "Backups will be saved with the extension '$BACKUP_EXT'."
echo -n "Continue? [y/N]: "
read -r CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "❌ Aborted. No files modified."
  exit 1
fi

# Perform substitutions with .bak backups
for file in $(find "$ROOT_DIR" -type f -name "*.sh"); do
  sed -i"$BACKUP_EXT" \
    -e 's/\<apt-get update\>/apt-get update/g' \
    -e 's/\<apt-get upgrade\>/apt-get upgrade/g' \
    -e 's/\<apt-get install\>/apt-get install/g' \
    -e 's/\<apt-get clean\>/apt-get clean/g' \
    -e 's/\<apt-get autoclean\>/apt-get autoclean/g' \
    -e 's/\<apt-get autoremove\>/apt-get autoremove/g' \
    "$file"
  echo "✅ Patched: $file (backup: $file$BACKUP_EXT)"
done

echo "🎉 All scripts updated safely with backups."

