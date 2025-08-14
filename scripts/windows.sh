#!/usr/bin/env bash
set -euo pipefail

# --- Options (override via env/args) ---
WT_FONT="${1:-Terminus (TTF)}"   # Use "Terminus Nerd Font" if you prefer glyphs
WT_SIZE="${2:-12}"

is_wsl() { grep -qi microsoft /proc/version 2>/dev/null; }
have() { command -v "$1" >/dev/null 2>&1; }

ARCH=$(uname -m)
DISTRO_ID=$(grep -oP '(?<=^ID=).*' /etc/os-release | tr -d '"')

echo "🖥️ Architecture detected: $ARCH"
echo "🐧 Distro detected: $DISTRO_ID"

# ---------- Linux package bootstrap ----------
if [[ "$DISTRO_ID" == "ubuntu" || "$DISTRO_ID" == "debian" ]]; then
  echo "🔄 Updating system..."
  sudo apt-get update
  sudo apt-get upgrade -y

  echo "📦 Installing base packages for Debian/Ubuntu..."
  sudo apt-get install -y \
    git tree curl emacs neovim build-essential \
    python3 python3-pip python3-venv \
    wslu xdg-utils shellcheck speedtest-cli \
    fonts-terminus || true   # TTF Terminus for GUI terminals

elif [[ "$DISTRO_ID" == "arch" ]]; then
  echo "🔄 Updating system..."
  sudo pacman -Syu --noconfirm

  echo "📦 Installing base packages for Arch Linux..."
  sudo pacman -S --noconfirm --needed \
    git tree curl emacs neovim base-devel \
    python python-pip wslu xdg-utils shellcheck speedtest-cli \
    terminus-font ttf-terminus-nerd || true

else
  echo "❌ Unsupported Linux distribution: $DISTRO_ID"
  exit 1
fi

echo "✅ Base setup complete for $DISTRO_ID ($ARCH)"

# ---------- WSL: set Windows Terminal default font ----------
if is_wsl && have powershell.exe; then
  echo "🪟 Detected WSL — configuring Windows Terminal font to '${WT_FONT}' (size ${WT_SIZE})"

  # Try to install a Terminus font on Windows host via winget (best-effort).
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command - <<'POWERSHELL' >/dev/null || true
$ErrorActionPreference = "SilentlyContinue"
if (Get-Command winget -ErrorAction SilentlyContinue) {
  winget install -e --id "NerdFonts.Terminusi386" --accept-package-agreements --accept-source-agreements 2>$null
  winget install -e --id "TerminusFont.TTF"       --accept-package-agreements --accept-source-agreements 2>$null
} else {
  Write-Host "winget not found on Windows; skipping font install."
}
POWERSHELL

  # Patch Windows Terminal settings.json (handles both Store and unpackaged installs)
  # Pass font/size via env so PowerShell reads $env:WT_FONT / $env:WT_SIZE
  env WT_FONT="${WT_FONT}" WT_SIZE="${WT_SIZE}" \
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command - <<'POWERSHELL' || true
$ErrorActionPreference = 'Stop'
$LocalAppData = [Environment]::GetFolderPath('LocalApplicationData')
$pkg = Get-ChildItem -Directory -Path (Join-Path $LocalAppData 'Packages') -Filter 'Microsoft.WindowsTerminal_*' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($pkg) {
  $settings = Join-Path $pkg.FullName 'LocalState\settings.json'
} else {
  $settings = Join-Path $LocalAppData 'Microsoft\Windows Terminal\settings.json'
}
if (-not (Test-Path $settings)) { Write-Host "Windows Terminal settings.json not found"; exit 0 }

$json = Get-Content $settings -Raw | ConvertFrom-Json

# Normalize schema: ensure $json.profiles.defaults.font exists
if (-not $json.profiles) { $json | Add-Member -NotePropertyName profiles -NotePropertyValue (@{}) }
if ($json.profiles -is [System.Collections.IEnumerable]) {
  $json.profiles = @{ defaults = @{}; list = $json.profiles }
}
if (-not $json.profiles.defaults) { $json.profiles.defaults = @{} }
if (-not $json.profiles.defaults.font) { $json.profiles.defaults.font = @{} }

# Apply font/size from env
if ($env:WT_FONT) { $json.profiles.defaults.font.face = $env:WT_FONT }
if ($env:WT_SIZE) { $json.profiles.defaults.font.size = [int]$env:WT_SIZE }

($json | ConvertTo-Json -Depth 100) | Set-Content -Path $settings -Encoding UTF8
Write-Host "✅ Patched Windows Terminal: $settings"
POWERSHELL

  echo "🔁 Restart Windows Terminal to apply the font change."
fi


echo '   - Example usage: bash scripts/windows.sh "Terminus Nerd Font" 12   # if you want glyphs'
echo ""
echo "💡 Next steps:"
echo "   - Optional: ./install_jupyter.sh"
echo "   - Optional: ./install_pdf_export.sh"
echo "   - Optional: ./shellcheck_dotfiles.sh"
echo "   - Optional: ./bsd-linux.sh   # to set TTY/console font on FreeBSD/Linux"

