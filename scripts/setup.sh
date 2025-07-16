#!/usr/bin/env bash
set -e

# Update package index
sudo apt update

# Upgrade existing packages
sudo apt upgrade -y

# Install packages
sudo apt install -y \
  git \
  curl \
  neovim \
  build-essential \
  python3 \
  python3-pip \
  wslu \
  xdg-utils \
  jupyter notebook \
  # add more here...

# Optional: cleanup
sudo apt clean
sudo apt autoclean
sudo apt autoremove -y

