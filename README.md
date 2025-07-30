# dotfiles
[![PowerShell](https://github.com/rcghpge/dotfiles/actions/workflows/powershell.yml/badge.svg)](https://github.com/rcghpge/dotfiles/actions/workflows/powershell.yml)
[![Shell Lint](https://github.com/rcghpge/dotfiles/actions/workflows/lint.yml/badge.svg)](https://github.com/rcghpge/dotfiles/actions/workflows/lint.yml)

This repository contains unified dotfiles for:

- Windows 10/11 (Bash: Git Bash, WSL)
- FreeBSD (bash and sh)
- Linux distros (bash and sh)

## Structure

- `common/`: Shared configurations (aliases, exports, functions).
- `windows/`: Windows-specific dotfiles.
- `freebsd/`: FreeBSD-specific dotfiles.
- `linux/`: Linux-specific dotfiles.
- `scripts/`: Setup and installation scripts.

## Install

```bash
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash install.sh
```
##  Clean Up with `bash_env_clean.sh`

After installation, you can run the environment cleanup script to free up space from common development caches:
```bash
# Be sure to set permissions if need (chmod +x)
bash bash_env_clean.sh

# With permissions set
./bash_env_clean.sh
```

This will:
- Show top disk usage in your home directory
- Delete common cache directories if they exist:

- `~/.cache/huggingface`
- `~/.cache/rattler`
- `~/.cache/kagglehub`
- `~/.cache/pip`

Output looks like:
```bash
🔍 Initial disk usage in /home/yourname
2.1G    /home/yourname/.cache
...

🧹 Deletig Hugging Face cache...
🧹 Dleting Rattler (Pixi) cache...
🧹 Deleting pip cache...
```
No root access needed. Run it anytime to keep your environment lean and clean.

## License

MIT

---
