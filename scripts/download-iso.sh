#!/usr/bin/env bash
# download-iso.sh — Fetch latest ISOs for Linux distributions.
# Validate script logic before running. Refine for modular cross-platform builds - TODO.

set -euo pipefail
mkdir -p ~/isos
cd ~/isos

echo "📥 Downloading latest Linux ISOs..."

# Ubuntu 24.04
curl -L -o ubuntu-24.04.iso https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso

# Arch Linux
curl -L -o archlinux-latest.iso https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso

# Fedora Workstation (latest stable release)
curl -L -o fedora-workstation.iso https://download.fedoraproject.org/pub/fedora/linux/releases/40/Workstation/x86_64/iso/Fedora-Workstation-Live-x86_64-40-1.14.iso

# Debian Stable (Bookworm)
curl -L -o debian-12.iso https://cdimage.debian.org/debian-cd/current/amd64/iso-dvd/debian-12.5.0-amd64-DVD-1.iso

# Rocky Linux 9 (latest minor)
curl -L -o rocky-9.iso https://download.rockylinux.org/pub/rocky/9/isos/x86_64/Rocky-9.3-x86_64-dvd.iso

# Kali Linux (weekly)
curl -L -o kali-linux.iso https://cdimage.kali.org/kali-weekly/kali-linux-2024.2a-installer-amd64.iso

echo "✅ All ISOs downloaded to ~/isos"
