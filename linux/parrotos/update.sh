#!/usr/bin/env bash
# Update Local ParrotOS Environment
# This Bash script will update your local ParrotOS computing environment

set -euox

# Warning: runs with root privileges (sudo).
# Check relevant technical documentation before running.
sudo apt update && sudo apt full-upgrade -y
sudo apt autoremove && sudo apt autoclean
