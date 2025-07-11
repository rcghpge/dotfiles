#!/usr/bin/env bash

set -e

echo "🛠️ Installing dotfiles..."

OS=""
if grep -qi "FreeBSD" /etc/os-release 2>/dev/null || uname | grep -qi "FreeBSD"; then
    OS="freebsd"
elif grep -qi "Microsoft" /proc/version 2>/dev/null; then
    OS="windows"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    OS="windows"
elif grep -qi "linux" /proc/version 2>/dev/null || [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
else
    echo "❌ Unsupported OS"
    exit 1
fi

echo "Detected OS: $OS"

ln -sf "$PWD/common/aliases" ~/.aliases
ln -sf "$PWD/common/exports" ~/.exports
ln -sf "$PWD/common/functions" ~/.functions

if [[ "$OS" == "windows" ]]; then
    ln -sf "$PWD/windows/bash_profile" ~/.bash_profile
    ln -sf "$PWD/windows/bashrc" ~/.bashrc
    ln -sf "$PWD/windows/profile" ~/.profile
elif [[ "$OS" == "freebsd" ]]; then
    ln -sf "$PWD/freebsd/bash_profile" ~/.bash_profile
    ln -sf "$PWD/freebsd/bashrc" ~/.bashrc
    ln -sf "$PWD/freebsd/profile" ~/.profile
    ln -sf "$PWD/freebsd/shrc" ~/.shrc
elif [[ "$OS" == "linux" ]]; then
    ln -sf "$PWD/linux/bash_profile" ~/.bash_profile
    ln -sf "$PWD/linux/bashrc" ~/.bashrc
    ln -sf "$PWD/linux/profile" ~/.profile
    ln -sf "$PWD/linux/shrc" ~/.shrc
fi

echo "✅ Done! Restart your shell or run: source ~/.bashrc"
