<#
.SYNOPSIS
  Install Fastfetch CLI, Speedtest CLI, Nano, and essential development tools via winget.

.DESCRIPTION
  Installs a curated set of CLI tools on Windows (or from WSL via powershell.exe) using winget.
  Includes Fastfetch, Speedtest, Nano, Git, Neovim, and Make. Supports optional extras and
  machine-wide scope (when supported by the package). Analyzer-friendly: no Write-Host, no empty catches.

.PARAMETER AllUsers
  Install packages for all users on the machine (if supported by the package).

.PARAMETER IncludeOptional
  Install optional extras (e.g., 7-Zip, Oh My Posh) in addition to essentials.

.EXAMPLE
  PS> ./pwsh-install.ps1
  Installs Fastfetch, Speedtest, Nano, and essential tools for the current user.

.EXAMPLE
  PS> ./pwsh-install.ps1 -AllUsers
  Installs the same toolset machine-wide.

.EXAMPLE
  PS> ./pwsh-install.ps1 -IncludeOptional
  Also installs 7-Zip and Oh My Posh.

.EXAMPLE
  PS> ./pwsh-install.ps1 -WhatIf
  Simulate actions without making changes.

.NOTES
  Created: 2025-08-14
  Author: rcghpge (https://github.com/rcghpge)
  License: MIT — https://opensource.org/licenses/MIT
  Version: 0.1.2
  Repository: https://github.com/rcghpge/dotfiles
#>

[CmdletBinding(SupportsShouldProcess)]
param(
  [switch]$AllUsers,
  [switch]$IncludeOptional
)

Set-StrictMode -Version Latest
$InformationPreference = 'Continue'

function Get-WingetBinary {
  [CmdletBinding()]
  param()
  $candidates = @(
    'winget',
    'winget.exe',
    "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe",
    'C:\Windows\System32\winget.exe'
  )
  foreach ($c in $candidates) {
    try {
      $cmd = Get-Command -Name $c -ErrorAction Stop
      return $cmd.Source
    } catch {
      Write-Verbose "Winget candidate not found: $c  ($_)"  # no empty catch
    }
  }
  return $null
}

$Winget = Get-WingetBinary
if (-not $Winget) {
  Write-Error "winget not found. Run in Windows PowerShell/Terminal, or from WSL via 'powershell.exe'."
  exit 1
}

function Install-WingetPackage {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)] [string]$Id,
    [string]$Name = $Id,
    [switch]$AllUsersParam
  )

  $wingetArgs = @('install','-e','--id', $Id, '--accept-package-agreements','--accept-source-agreements')
  if ($AllUsersParam) { $wingetArgs += @('--scope','machine') }

  if ($PSCmdlet.ShouldProcess($Name, "winget $($wingetArgs -join ' ')")) {
    Write-Information "Installing $Name ($Id)…"
    $proc = Start-Process -FilePath $Winget -ArgumentList $wingetArgs -NoNewWindow -PassThru -Wait
    if ($proc.ExitCode -ne 0) {
      Write-Verbose "winget exit code for $Name: $($proc.ExitCode)"
      throw "Failed to install $Name ($Id)"
    }
  }
}

function Test-CommandAvailable {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$CommandName)
  $cmd = Get-Command -Name $CommandName -ErrorAction SilentlyContinue
  return [bool]$cmd
}

# --- Essentials ---
$packages = @(
  @{ Id = 'Git.Git';                 Name = 'Git';             Cmd = 'git' }
  @{ Id = 'Neovim.Neovim';           Name = 'Neovim';          Cmd = 'nvim' }
  @{ Id = 'GNU.Nano';                Name = 'GNU Nano';        Cmd = 'nano' }
  @{ Id = 'Fastfetch.cli';           Name = 'Fastfetch CLI';   Cmd = 'fastfetch' }
  @{ Id = 'Ookla.Speedtest';         Name = 'Speedtest CLI';   Cmd = 'speedtest' }
  @{ Id = 'GnuWin32.Make';           Name = 'make (GnuWin32)'; Cmd = 'make' }
)

# --- Optional extras ---
if ($IncludeOptional) {
  $packages += @(
    @{ Id = '7zip.7zip';             Name = '7-Zip';           Cmd = '7z' }
    @{ Id = 'JanDeDobbeleer.OhMyPosh'; Name = 'Oh My Posh';    Cmd = 'oh-my-posh' }
  )
}

# --- Install loop ---
foreach ($p in $packages) {
  try {
    Install-WingetPackage -Id $p.Id -Name $p.Name -AllUsersParam:$AllUsers
  } catch {
    Write-Information "Skipping $($p.Name): $($_.Exception.Message)"
  }
}

# --- Verify availability ---
Write-Information "Verifying installed commands…"
$report = foreach ($p in $packages) {
  $ok = Test-CommandAvailable -CommandName $p.Cmd
  [pscustomobject]@{
    Tool  = $p.Name
    Id    = $p.Id
    Cmd   = $p.Cmd
    Found = $ok
    Path  = if ($ok) { (Get-Command $p.Cmd).Source } else { $null }
  }
}
$report | Format-Table -AutoSize | Out-String | Write-Output

Write-Information "Done. Open a new Windows Terminal/PowerShell tab to ensure PATH is refreshed."
Write-Information "Tip: add -Verbose for details, or -WhatIf to simulate."

