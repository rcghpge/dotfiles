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
    python3 python3-pip python3-venv python-is-python3 \
    wslu xdg-utils shellcheck speedtest-cli \
    fonts-terminus fastfetch || true   # Terminus font + Fastfetch (Linux side)

elif [[ "$DISTRO_ID" == "arch" ]]; then
  echo " ^=^t^d Updating system..."
  sudo pacman -Syu --noconfirm

  echo " ^=^s Installing base packages for Arch Linux (official repos)..."
  # Official repo packages (safe for Arch)
  PAC_PKGS=(
    git tree curl emacs neovim base-devel
    python python-pip xdg-utils shellcheck speedtest-cli
    nano less fastfetch
    terminus-font   # console Terminus font (official)
  )

  # Filter to only those in official Arch Linux repos 
  TO_INSTALL=()
  for p in "${PAC_PKGS[@]}"; do
    if pacman -Si "$p" >/dev/null 2>&1; then
      TO_INSTALL+=("$p")
    else
      echo " [skip] $p not in official repos"
    fi
  done

  if ((${#TO_INSTALL[@]})); then
    sudo pacman -S --noconfirm --needed "${TO_INSTALL[@]}"
  else
    echo " [info] Nothing to install from official repos."
  fi

  echo " ^=^s (Optional) Installing AUR packages if helper is available..."
  AUR_PKGS=(
    wslu               # AUR on Arch (Ubuntu WSL tool)
    ttf-terminus-nerd  # Nerd font variant (AUR)
  )

  # Detect an AUR helper
  AUR_HELPER=""
  if command -v paru >/dev/null 2>&1; then
    AUR_HELPER="paru"
  elif command -v yay >/dev/null 2>&1; then
    AUR_HELPER="yay"
  fi

  if [[ -n "$AUR_HELPER" ]]; then
    for a in "${AUR_PKGS[@]}"; do
      if ! pacman -Qi "$a" >/dev/null 2>&1; then
        "$AUR_HELPER" -S --noconfirm "$a" || echo " [warn] Failed AUR install: $a"
      fi
    done
  else
    echo " [note] No AUR helper (paru/yay) found; skipping AUR packages: ${AUR_PKGS[*]}"
  fi
else
  echo " ^}^l Unsupported Linux distribution: $DISTRO_ID"
  exit 1
fi

# --- Pixi (Prefix.dev) install (Arch/WSL safe) ---
install_pixi() {
  if command -v pixi >/dev/null 2>&1; then
    echo "[OK] pixi already installed: $(pixi --version)"
    return 0
  fi

  echo "[INFO] Installing pixi from official installer..."
  # Install as the current (non-root) user so it lands in ~/.pixi/bin
  # If your script runs as root, use: sudo -u "$SUDO_USER" bash -lc 'curl ...'
  curl -fsSL https://pixi.sh/install.sh | bash

  # Ensure current shell can find it right away
  export PATH="$HOME/.pixi/bin:$PATH"
  hash -r

  if ! command -v pixi >/dev/null 2>&1; then
    echo "[ERROR] pixi not found on PATH after install. Check that ~/.pixi/bin exists and PATH is exported."
    echo "        Try: export PATH=\"\$HOME/.pixi/bin:\$PATH\""
    return 1
  fi

  echo "[OK] pixi installed: $(pixi --version)"
}

install_pixi

echo "✅ Base setup complete for $DISTRO_ID ($ARCH) — Fastfetch available on Linux side"

# ---------- WSL: set Windows Terminal default font & install Fastfetch ----------
if is_wsl && have powershell.exe; then
  echo "🪟 Detected WSL — configuring Windows Terminal font to '${WT_FONT}' (size ${WT_SIZE}) and installing Fastfetch on Windows side"

  # Try to install Windows-side bits via winget (best-effort).
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command - <<'POWERSHELL' >/dev/null || true
$ErrorActionPreference = "SilentlyContinue"
if (Get-Command winget -ErrorAction SilentlyContinue) {
  # Fonts
  winget install -e --id "NerdFonts.Terminusi386" --accept-package-agreements --accept-source-agreements 2>$null
  winget install -e --id "TerminusFont.TTF"       --accept-package-agreements --accept-source-agreements 2>$null
  # Fastfetch CLI (Windows side)
  winget install -e --id "Fastfetch.cli"          --accept-package-agreements --accept-source-agreements 2>$null
} else {
  Write-Host "winget not found on Windows; skipping font/Fastfetch install."
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
  echo "ℹ️ Fastfetch installed on both Linux (WSL distro) and Windows sides."
fi

echo '   - Example usage: bash scripts/windows.sh "Terminus Nerd Font" 12   # if you want glyphs'
echo ""
echo "💡 Next steps:"
echo "   - Run 'fastfetch' in Linux or Windows Terminal to see system info"
echo "   - Optional: ./install_jupyter.sh"
echo "   - Optional: ./install_pdf_export.sh"
echo "   - Optional: ./shellcheck_dotfiles.sh"
echo "   - Optional: ./bsd-linux.sh   # to set TTY/console font on FreeBSD/Linux"

