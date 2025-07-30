#!/bin/bash
# This bash script cleans cached memory on your machine (Hugging Face, 
# Pixi, pip, KaggleHub) and orphaned Python/Jupyter files from $HOME.

echo "🔍 Initial disk usage in /home/$USER"
du -h --max-depth=1 ~ | sort -hr | head -n 15
echo ""

# Hugging Face
if [ -d "$HOME/.cache/huggingface" ]; then
  echo "🧹 Deleting Hugging Face cache..."
  rm -rf "$HOME/.cache/huggingface"
fi

# Rattler (Pixi)
if [ -d "$HOME/.cache/rattler" ]; then
  echo "🧹 Deleting Rattler (Pixi) cache..."
  rm -rf "$HOME/.cache/rattler"
fi

# KaggleHub (optional)
if [ -d "$HOME/.cache/kagglehub" ]; then
  echo "🧹 Deleting KaggleHub cache..."
  rm -rf "$HOME/.cache/kagglehub"
fi

# Pip cache (optional)
if [ -d "$HOME/.cache/pip" ]; then
  echo "🧹 Deleting pip cache..."
  rm -rf "$HOME/.cache/pip"
fi

# Optional: Remove __pycache__ and .ipynb_checkpoints across home
echo "🧹 Removing __pycache__ and Jupyter checkpoints..."
find "$HOME" -type d -name "__pycache__" -exec rm -rf {} +
find "$HOME" -type d -name ".ipynb_checkpoints" -exec rm -rf {} +

echo ""
echo "✅ Cleanup complete."
echo ""

# Post-clean disk check
echo "📦 Final disk usage in /home/$USER"
du -h --max-depth=1 ~ | sort -hr | head -n 15

