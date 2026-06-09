# scripts

This is a collection of Bash and Powershell scripts for Linux, WSL, and Windows for now. Example usage will be added as the repository grows

---

### Windows Powershell `optimize-wsl-vhd.ps1`

Optimize VHD's on Windows for storage bloat:
```pwsh
Set-ExecutionPolicy RemoteSigned -Scope Process
# pass a -nb or -noBackup flag to skip generating a backup
.\optimize-wsl-vhd.ps1 -nb 
```

### `pswh-install.exe`

Installs pwsh essentials:
```pwsh
# Dry run with verbose
pwsh -NoProfile -File .\scripts\pwsh-install.ps1 -Verbose -WhatIf

# Real run (current user)
pwsh -NoProfile -File .\scripts\pwsh-install.ps1 -Verbose

# Machine-wide (admin)
Start-Process pwsh -Verb RunAs -ArgumentList '-NoProfile','-File',"$PWD\scripts\pwsh-install.ps1",'-AllUsers','-Verbose'
```

---

### Bash (Linux / WSL) on Windows `windows.sh` 

Bootstrap script for dev environments:
```bash
bash windows.sh
```

Supports both Ubuntu/Debian and Arch Linux (including ArchWSL).
Automatically detects distro and architecture (x86_64, aarch64) and installs system-specific dev tools.
Should work on native-Ubuntu/Debian and Arch Linux

---

### JupyterLab `install_jupyter.sh`

Installs JupyterLab inside a virtual environment (~/venvs/jupyter) with optional browser auto-launch support.

📦 Usage:
```bash
# Standard install (will prompt for browser preference)
./install_jupyter.sh

# Force install with browser auto-launch
./install_jupyter.sh --with-browser

# Force install without browser auto-launch
./install_jupyter.sh --no-browser
```

💡 Notes:

- On Arch Linux, make sure `xdg-utils` is installed for browser auto-launch.
- On WSL, the script will use `wslview` if available.
- Adds Jupyter to `~/.local/bin` for convenience.

You can launch JupyterLab anytime with:
```bash
jupyter lab

# Or - (still baking out the installer)
jupyter lab --no-browser --ip=127.0.0.1 --port=8888 & sleep 3 && xdg-open "$(jupyter lab list 2>/dev/null | grep -o 'http://127.0.0.1:8888[^ ]*' | head -n1 || echo http://127.0.0.1:8888)"
```

---

