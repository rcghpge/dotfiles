#!/usr/bin/env bash
set -e

# Parse CLI flags
disable_browser_prompt=true

for arg in "$@"; do
  case $arg in
    --no-browser)
      browser_setting=false
      disable_browser_prompt=false
      ;;
    --with-browser)
      browser_setting=true
      disable_browser_prompt=false
      ;;
    *)
      echo "Unknown option: $arg"
      echo "Usage: $0 [--no-browser | --with-browser]"
      exit 1
      ;;
  esac
done

# Detect OS and environment for browser compatibility
OS_ID=$(grep -oP '(?<=^ID=).*' /etc/os-release 2>/dev/null || echo "unknown")
IS_WSL=false
IS_HEADLESS=false

# Detect WSL
if grep -qi microsoft /proc/version 2>/dev/null; then
  IS_WSL=true
fi

# Detect headless (no display)
if [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]; then
  IS_HEADLESS=true
fi

# Warn if browser auto-launch may fail
if [ "${browser_setting:-false}" = true ]; then
  echo "🔍 Verifying system compatibility for browser auto-launch..."
  if $IS_WSL; then
    echo "⚠️  Running in WSL — requires 'wslu' and 'wslview' for browser launch."
  elif [ "$OS_ID" = "arch" ] && $IS_HEADLESS; then
    echo "⚠️  Arch Linux without graphical session detected — browser may not auto-launch."
  elif $IS_HEADLESS; then
    echo "⚠️  No DISPLAY environment variable — headless session may block auto-launch."
  else
    echo "✅ Browser auto-launch appears to be supported."
  fi
fi

# Define virtual environment location
VENV_DIR="$HOME/venvs/jupyter"

# Create virtual environment if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
  echo "📂 Creating Python virtual environment at $VENV_DIR..."
  python3 -m venv "$VENV_DIR"
else
  echo "✅ Virtual environment already exists at $VENV_DIR"
fi

# Activate virtual environment
# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"

# Upgrade pip
echo "⬆️  Upgrading pip..."
pip install --upgrade pip

# Install JupyterLab and related packages
echo "📦 Installing JupyterLab and core dependencies..."
pip install \
  jupyterlab \
  notebook \
  ipykernel \
  nbconvert \
  ipywidgets \
  jupyterlab-widgets

# Optionally symlink to ~/.local/bin for global access
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
ln -sf "$VENV_DIR/bin/jupyter" "$LOCAL_BIN/jupyter"

# Ensure ~/.local/bin is in PATH
if ! echo "$PATH" | grep -q "$LOCAL_BIN"; then
  echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> "$HOME/.bashrc"
  echo "🛠️  Added ~/.local/bin to PATH in ~/.bashrc"
fi

# Configure browser launch behavior
CONFIG_DIR="$HOME/.jupyter"
CONFIG_FILE="$CONFIG_DIR/jupyter_lab_config.py"
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "🛠️  Generating JupyterLab config..."
  jupyter lab --generate-config
fi

if [ "$disable_browser_prompt" = true ]; then
  echo -n "Would you like to disable JupyterLab's browser auto-launch? [y/N]: "
  read -r DISABLE_BROWSER
  if [[ "$DISABLE_BROWSER" =~ ^[Yy]$ ]]; then
    browser_setting=false
  else
    browser_setting=true
  fi
fi

if [ "$browser_setting" = false ]; then
  echo "c.ServerApp.open_browser = False" >> "$CONFIG_FILE"
  echo "✅ Auto-launch disabled in $CONFIG_FILE"
else
  echo "c.ServerApp.open_browser = True" >> "$CONFIG_FILE"
  echo "✅ Auto-launch enabled in $CONFIG_FILE"
fi

# Confirm Jupyter installation completion
echo "✅ JupyterLab setup complete. Launch with: jupyter lab"

# Attempt to auto-launch server and browser if enabled
if [ "${browser_setting:-false}" = true ]; then
  echo "🚀 Starting JupyterLab server..."

  # Launch server in background
  jupyter lab --no-browser --ip=127.0.0.1 --port=8888 &

  # Give it time to initialize
  sleep 3

  # Try to extract running URL with token
  LAB_URL=$(jupyter lab list 2>/dev/null | grep -o 'http://127.0.0.1:8888/.*' | head -n 1)
  LAB_URL="${LAB_URL:-http://127.0.0.1:8888}"

  echo "🌐 Attempting to open browser..."
  if command -v xdg-open &>/dev/null; then
    xdg-open "$LAB_URL"
  elif command -v wslview &>/dev/null; then
    wslview "$LAB_URL"
  else
    echo "🔗 Unable to open automatically. Please open manually: $LAB_URL"
  fi
else
  echo "🔗 JupyterLab is ready. Visit: http://127.0.0.1:8888"
fi

# Example usage:
#   ./install_jupyter.sh
#
# Or:
#   ./install_jupyter.sh --no-browser
#
# Or:
#   ./install_jupyter.sh --with-browser
