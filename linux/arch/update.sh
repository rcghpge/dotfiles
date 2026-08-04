#!/usr/bin/env bash
# Update Local Arch Linux or LnOS Environment
# This Bash script will update your local Arch Linux or LnOS computing environment

set -euox

# Warning: runs with root privileges (sudo).
# Check relevant technical documentation before running.
sudo pacman -Syu
