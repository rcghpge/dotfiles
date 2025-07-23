#!/usr/bin/env bash
set -e

echo "🔄 Updating system..."
sudo apt-get update
sudo apt-get upgrade -y

echo "📦 Installing WSL and development essentials..."
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

echo "✅ Base setup complete."

echo "💡 Next steps:"
echo "   - Run './install_jupyter.sh' (optional) if you want to install JupyterLab"
echo "   - Run './install_pdf_export.sh' (optional) if you want to export notebooks to PDF"
echo "   - Run './shellcheck_dotfiles.sh' (optional) if you want to check shell linting on your dotfiles"
