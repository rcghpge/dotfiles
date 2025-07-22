#!/usr/bin/env bash
set -e

echo "📦 Installing PDF export dependencies (LaTeX + Pandoc)..."

sudo apt-get update
sudo apt-get install -y \
  pandoc \
  texlive-xetex \
  texlive-fonts-recommended \
  texlive-plain-generic

echo "✅ Jupyter nbconvert PDF export dependencies installed."

