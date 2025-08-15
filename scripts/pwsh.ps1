# pwsh.ps1
# Run this in an elevated (Administrator) PowerShell

$packages = @(
    # Essentials
    @{ Id = "Git.Git";                  Name = "Git" },
    @{ Id = "Neovim.Neovim";            Name = "Neovim" },
    @{ Id = "GnuWin32.Curl";            Name = "cURL" },
    @{ Id = "Microsoft.PowerShell";     Name = "PowerShell" },

    # CLIs
    @{ Id = "Fastfetch.cli";            Name = "Fastfetch CLI" },
    @{ Id = "Ookla.Speedtest";          Name = "Speedtest CLI" }
)

foreach ($pkg in $packages) {
    Write-Host "📦 Installing $($pkg.Name)..." -ForegroundColor Cyan
    try {
        winget install -e --id $pkg.Id `
            --accept-package-agreements --accept-source-agreements
    }
    catch {
        Write-Warning "Failed to install $($pkg.Name)"
    }
}

Write-Host "✅ All installations attempted. Restart your terminal to ensure PATH updates." -ForegroundColor Green

