# scripts

This is a collection of Bash and Powershell scripts for Linux, WSL, and Windows for now. Example usage will be added as the repository grows

---

## Windows Powershell:

Optimize VHD's on Windows for storage bloat:
```bash
Set-ExecutionPolicy RemoteSigned -Scope Process
# pass a -nb or -noBackup flag to skip generating a backup
.\optimize-wsl-vhd.ps1 -nb 
```

