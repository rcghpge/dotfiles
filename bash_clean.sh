#!/bin/bash
# This bash script cleans cached memory on your machine (Hugging Face,
# Pixi, pip, KaggleHub) and orphaned Python/Jupyter files from $HOME.

echo "============================================================"
echo "🖥️  Bash Shell disk cleanup running..."
echo "============================================================"
echo "🔍 Initial disk usage in /home/$USER"
echo "------------------------------------------------------------"
du -h --max-depth=1 ~ | sort -hr | head -n 15
echo ""

# Pixi
echo "🧹 Cleaning all .pixi directories..."

# Capture all .pixi paths first (no pipe in loop)
mapfile -t pixi_dirs < <(find ~ -maxdepth 6 -type d -name ".pixi" 2>/dev/null)

for pixi_dir in "${pixi_dirs[@]}"; do
  project_dir=$(dirname "$pixi_dir")
  echo "📂 Processing: $project_dir"

  before=$(du -sh "$pixi_dir" 2>/dev/null | cut -f1 || echo "0B")

  # Clean deep cache
  find "$pixi_dir/envs" -mindepth 4 -delete 2>/dev/null || true
  find "$pixi_dir/activation-env-v0" -mindepth 1 -delete 2>/dev/null || true

  after=$(du -sh "$pixi_dir" 2>/dev/null | cut -f1 || echo "0B")
  echo "✅ $pixi_dir: $before → $after"
done

echo "✅ All .pixi environments cleanup complete."

# Anaconda/Conda
if [ -d "$HOME/anaconda3" ] && command -v conda >/dev/null 2>&1; then
  echo "🧹 Cleaning up Anaconda/Conda cache..."
  before=$(du -sh "$HOME/anaconda3" | cut -f1)
  conda clean --all --yes
  after=$(du -sh "$HOME/anaconda3" | cut -f1)
  echo "✅ Conda cache cleaned: $before → $after"
else
  echo ""
  echo "⚠️ No Anaconda3 directory or conda command not found. Skipping..."
  echo "------------------------------------------------------------"
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
echo ""
echo "🧹 Removing __pycache__ and Jupyter checkpoints..."
find "$HOME" -type d -name "__pycache__" -exec rm -rf {} +
find "$HOME" -type d -name ".ipynb_checkpoints" -exec rm -rf {} +

# General ~/.cache Cleanup. Final cleanup
if [ -d "$HOME/.cache" ]; then
  echo "🧹 Cleaning up ~/.cache directory..."
  before=$(du -sh "$HOME/.cache" | cut -f1)

  # Removes all files/folders inside ~/.cache without deleting the directory itself
  find "$HOME/.cache" -mindepth 4 -delete

  after=$(du -sh "$HOME/.cache" 2>/dev/null | cut -f1)
  echo "✅ Cache cleaned: $before → ${after:-0B}"
  echo "✅ Cleanup complete."

else
  echo "⚠  No ~/.cache directory found. Skipping..."
fi

# Post-clean disk check
printf "\n"
echo "📦 Final disk usage in /home/$USER"
echo "------------------------------------------------------------"
du -h --max-depth=1 ~ | sort -hr | head -n 15

