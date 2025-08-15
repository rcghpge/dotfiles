<#
.SYNOPSIS
  Install Fastfetch CLI, Speedtest CLI, Nano, and essential development tools via winget.

.DESCRIPTION
  This script installs a curated list of essential CLI tools on Windows systems 
  (or from WSL via powershell.exe) using winget. It includes Fastfetch CLI for 
  system info display, Ookla Speedtest CLI for bandwidth testing, Nano, Git, 
  Neovim, and other utilities. It supports optional installation of extra tools 
  and machine-wide scope when supported by the package.

.PARAMETER AllUsers
  Installs packages for all users on the machine (if supported by the package).

.PARAMETER IncludeOptional
  Installs additional optional tools (e.g., 7-Zip, Oh My Posh) in addition to essentials.

.EXAMPLE
  PS> ./pwsh-essentials.ps1
  Installs Fastfetch, Speedtest, Nano, and essential CLI tools for the current user.

  PS> ./pwsh-essentials.ps1 -AllUsers
  Installs Fastfetch, Speedtest, Nano, and essential CLI tools machine-wide.

  PS> ./pwsh-essentials.ps1 -IncludeOptional
  Installs Fastfetch, Speedtest, Nano, essentials, and optional extras like 7-Zip and Oh My Posh.

  PS> ./pwsh-essentials.ps1 -WhatIf
  Simulates the installation without making changes.

.NOTES
  Created: 2025-08-14
  Author: rcghpge (https://github.com/rcghpge)
  License: MIT — https://opensource.org/licenses/MIT
  Version: 0.1.1
  Repository: https://github.com/rcghpge/dotfiles
#>

[CmdletBinding(SupportsShouldProcess)]
param(
  [switch]$AllUsers,          # install scope (if the package supports it)
  [switch]$IncludeOptional    # add a few extra tools
)

Set-StrictMode -Version Latest
$InformationPreference = 'Continue'

function Get-WingetBinary {
  $candidates = @(
    "winget",
    "winget.exe",
    "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe",
    "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller*",
    "C:\Windows\System32\winget.exe"
  )
  foreach ($c in $candidates) {
    try {
      $cmd = Get-Command $c -ErrorAction Stop
      return $cmd.Source
    } catch { }
  }
  return $null
}

$Winget = Get-WingetBinary
if (-not $Winget) {
  Write-Error "winget not found. Run this in Windows PowerShell/Terminal, or from WSL using 'powershell.exe'."
  exit 1
}

function Install-WingetPackage {
  param(
    [Parameter(Mandatory)] [string]$Id,
    [string]$Name = $Id
  )
  $args = @('install','-e','--id', $Id, '--accept-package-agreements','--accept-source-agreements')
  if ($AllUsers) { $args += '--scope','machine' }

  if ($PSCmdlet.ShouldProcess($Name, "winget install $Id")) {
    Write-Information "Installing $Name ($Id)…"
    $proc = Start-Process -FilePath $Winget -ArgumentList $args -NoNewWindow -PassThru -Wait
    if ($proc.ExitCode -ne 0) {
      Write-Verbose "winget exit code: $($proc.ExitCode)"
      throw "Failed to install $Name ($Id)"
    }
  }
}

function Test-CommandAvailable {
  param([Parameter(Mandatory)][string]$CommandName)
  $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue
  return [bool]$cmd
}

# --- Essentials ---
$packages = @(
  @{ Id = 'Git.Git';            Name = 'Git';             Cmd = 'git' }
  @{ Id = 'Neovim.Neovim';      Name = 'Neovim';          Cmd = 'nvim' }
  @{ Id = 'GNU.Nano';           Name = 'GNU Nano';        Cmd = 'nano' }
  @{ Id = 'Fastfetch.cli';      Name = 'Fastfetch CLI';   Cmd = 'fastfetch' }
  @{ Id = 'Ookla.Speedtest';    Name = 'Speedtest CLI';   Cmd = 'speedtest' }
  @{ Id = 'GnuWin32.Make';      Name = 'make (GnuWin32)'; Cmd = 'make' }
)

# --- Optional extras ---
if ($IncludeOptional) {
  $packages += @(
    @{ Id = '7zip.7zip';        Name = '7-Zip';           Cmd = '7z' }
    @{ Id = 'JanDeDobbeleer.OhMyPosh'; Name = 'Oh My Posh'; Cmd = 'oh-my-posh' }
  )
}

# --- Install loop ---
foreach ($p in $packages) {
  try {
    Install-WingetPackage -Id $p.Id -Name $p.Name
  } catch {
    Write-Information "Skipping $($p.Name): $($_.Exception.Message)"
  }
}

# --- Verify availability ---
Write-Information "Verifying installed commands…"
$report = foreach ($p in $packages) {
  $ok = Test-CommandAvailable -CommandName $p.Cmd
  [pscustomobject]@{
    Tool   = $p.Name
    Id     = $p.Id
    Cmd    = $p.Cmd
    Found  = $ok
    Path   = if ($ok) { (Get-Command $p.Cmd).Source } else { $null }
  }
}
$report | Format-Table -AutoSize | Out-String | Write-Output

Write-Information "Done. Open a new Windows Terminal/PowerShell tab to ensure updated PATH is loaded."
Write-Information "Tip: run with -Verbose for more details, or -WhatIf to simulate."

