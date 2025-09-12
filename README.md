# dotfiles
[![PowerShell](https://github.com/rcghpge/dotfiles/actions/workflows/powershell.yml/badge.svg)](https://github.com/rcghpge/dotfiles/actions/workflows/powershell.yml)
[![Shell Lint](https://github.com/rcghpge/dotfiles/actions/workflows/lint.yml/badge.svg)](https://github.com/rcghpge/dotfiles/actions/workflows/lint.yml)

<center><img src="https://github.com/rcghpge/dotfiles/blob/main/assets/rcghpge.png?raw=true" width=100% alt="Windows 10 Pro dotfiles"></center>

This repository contains unified dotfiles for:

- Windows 10/11 (Bash: Git Bash, WSL, PowerShell)
- FreeBSD (bash and sh)
- Linux distributions (bash and sh)

## Structure

- `common/`: Shared configurations (aliases, exports, functions).
- `windows/`: Windows-specific dotfiles.
- `freebsd/`: FreeBSD-specific dotfiles.
- `linux/`: Linux-specific dotfiles.
- `scripts/`: Setup, installation, and utility scripts.

## Install

```bash
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash install.sh
```
##  Clean up with `bash-env-clean.sh`

After installation, you can run the environment cleanup script to free up disk space from common development caches in cached memory:
```bash
# Be sure to set permissions if needed (chmod +x)
bash bash-env-clean.sh

# With permissions set
./bash-env-clean.sh
```

This will:

Show top disk usage in your home directory and delete common cache directories if they exist:
- `~/.cache/huggingface`
- `~/.cache/rattler`
- `~/.cache/kagglehub`
- `~/.cache/pip`

Output looks like:
```bash
🔍 Initial disk usage in /home/yourname
2.1G    /home/yourname/.cache
...

🧹 Deleting Hugging Face cache...
🧹 Deleting Rattler (Pixi) cache...
🧹 Deleting pip cache...
```
No root access needed. Run it anytime to keep your environment lean and clean.

## License

MIT

---
