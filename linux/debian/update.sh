#!/usr/bin/env bash
# Update Local Debian Environment
# This Bash script will update your local Debian computing environment

set -eu

# Warning: runs with root privileges (sudo).
# Check relevant technical documentation before running.
sudo apt update && sudo apt full-upgrade -y
sudo apt autoremove && sudo apt autoclean
