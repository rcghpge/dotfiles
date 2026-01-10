#!/bin/sh
# This shell script cleans cached memory on your machine (Hugging Face,
# Pixi, pip, KaggleHub) and orphaned Python/Jupyter files from $HOME.


echo "============================================================"
echo "🖥️  Bourne Shell disk cleanup running..."
echo "============================================================"
echo "🔍 Initial disk usage in /home/$USER"
echo "------------------------------------------------------------"
du -h -d 1 ~ | sort -hr | head -n 15
echo ""

# Anaconda/Conda
if [ -d "$HOME/anaconda3" ] && command -v conda >/dev/null 2>&1; then
  echo "🧹 Cleaning up Anaconda/Conda cache..."
  before=$(du -sh "$HOME/anaconda3" | cut -f1)
  conda clean --all --yes
  after=$(du -sh "$HOME/anaconda3" | cut -f1)
  echo "✅ Conda cache cleaned: $before → $after"
else
  echo "⚠️ No Anaconda3 directory or conda command not found. Skipping..."
fi

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

# KaggleHub
if [ -d "$HOME/.cache/kagglehub" ]; then
  echo "🧹 Deleting KaggleHub cache..."
  rm -rf "$HOME/.cache/kagglehub"
fi

# Pip
if [ -d "$HOME/.cache/pip" ]; then
  echo "🧹 Deleting pip cache..."
  rm -rf "$HOME/.cache/pip"
fi

# __pycache__ and .ipynb_checkpoints across home
echo "🧹 Removing __pycache__ and Jupyter checkpoints..."
find "$HOME" -type d -name "__pycache__" -exec rm -rf {} +
find "$HOME" -type d -name ".ipynb_checkpoints" -exec rm -rf {} +


echo ""
echo "============================================================"
echo "✅ Cleanup complete."
echo "============================================================"

# Post-clean disk check
echo "📦 Final disk usage in /home/$USER"
echo "------------------------------------------------------------"
du -h -d 1 ~ | sort -hr | head -n 15

