#!/usr/bin/env bash
set -euo pipefail

ARCH=$(uname -m)
DISTRO_ID=$(grep -oP '(?<=^ID=).*' /etc/os-release | tr -d '"')

echo "🖥️ Architecture detected: $ARCH"
echo "🐧 Distro detected: $DISTRO_ID"

if [[ "$DISTRO_ID" == "ubuntu" || "$DISTRO_ID" == "debian" ]]; then
  echo "🔄 Updating system..."
  sudo apt-get update
  sudo apt-get upgrade -y

  echo "📦 Installing base packages for Debian/Ubuntu..."
  sudo apt-get install -y \
    git \
    curl \
    emacs \
    neovim \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    wslu \
    xdg-utils \
    shellcheck \
    speedtest-cli

elif [[ "$DISTRO_ID" == "arch" ]]; then
  echo "🔄 Updating system..."
  sudo pacman -Syu --noconfirm

  echo "📦 Installing base packages for Arch Linux..."
  sudo pacman -S --noconfirm --needed \
    git \
    curl \
    emacs \
    neovim \
    base-devel \
    python \
    python-pip \
    wslu \
    xdg-utils \
    shellcheck \
    speedtest-cli

else
  echo "❌ Unsupported Linux distribution: $DISTRO_ID"
  exit 1
fi

echo "✅ Base setup complete for $DISTRO_ID ($ARCH)"

echo "💡 Next steps:"
echo "   - Run './install_jupyter.sh' (optional) if you want to install JupyterLab"
echo "   - Run './install_pdf_export.sh' (optional) if you want to export notebooks to PDF"
echo "   - Run './shellcheck_dotfiles.sh' (optional) if you want to check shell linting on your dotfiles"

