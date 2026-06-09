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
  Installs the same toolset machine-wide (requires admin).

.EXAMPLE
  PS> ./pwsh-install.ps1 -IncludeOptional
  Also installs 7-Zip and Oh My Posh.

.EXAMPLE
  PS> ./pwsh-install.ps1 -WhatIf
  Simulate actions without making changes.

.NOTES
  Created: 2025-08-14
  Author: rcghpge (https://github.com/rcghpge)
  License: MIT - https://opensource.org/licenses/MIT
  Version: 0.1.6
  Repository: https://github.com/rcghpge/dotfiles
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [switch]$AllUsers,
  [switch]$IncludeOptional
)

Set-StrictMode -Version Latest
$InformationPreference = 'Continue'

function Test-Admin {
  [CmdletBinding()]
  param()
  try {
    $wi = [Security.Principal.WindowsIdentity]::GetCurrent()
    $wp = New-Object Security.Principal.WindowsPrincipal($wi)
    return $wp.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  } catch {
    Write-Verbose "Admin check failed: $($_.Exception.Message)"
    return $false
  }
}

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
      Write-Verbose "Winget candidate not found: $c  ($($_.Exception.Message))"
    }
  }
  return $null
}

$Winget = Get-WingetBinary
if (-not $Winget) {
  Write-Error "winget not found. Run in Windows PowerShell/Terminal, or from WSL via 'powershell.exe'."
  throw "winget is required"
}

if ($AllUsers -and -not (Test-Admin)) {
  Write-Information "AllUsers requested, but this session isn't elevated. Proceeding with per-user installs."
  $AllUsers = $false
}

function Initialize-WingetSource {
  [CmdletBinding()]
  param()
  try {
    $null = & $Winget source list 2>&1
  } catch {
    Write-Information "winget sources look unhealthy; resetting."
    try {
      & $Winget source reset --force | Out-Null
    } catch {
      Write-Verbose "winget source reset failed: $($_.Exception.Message)"
    }
  }
  try {
    & $Winget source update | Out-Null
  } catch {
    Write-Verbose "winget source update failed: $($_.Exception.Message)"
  }
}

# Back-compat alias (old name  new function)
Set-Alias -Name Ensure-WingetSources -Value Initialize-WingetSource

# Optional fallback IDs if a primary ID isn't found (-1978335212)
$WingetIdFallbacks = @{
  'Fastfetch-cli.Fastfetch' = @('fastfetch-cli.fastfetch')
  'Ookla.Speedtest.CLI'     = @('Ookla.SpeedtestbyOokla')  # MS Store variant, may be blocked in some environments
  'GnuWin32.Make'           = @('ezwinports.make')
}

function Install-WingetPackage {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory)] [string]$Id,
    [string]$Name = $Id,
    [switch]$AllUsersParam
  )

  $baseArgs = @('install','-e','--id', $Id, '--accept-package-agreements','--accept-source-agreements')
  if ($AllUsersParam) { $baseArgs += @('--scope','machine') }

  $attemptIds = ,$Id + ($WingetIdFallbacks[$Id] | ForEach-Object { $_ })
  foreach ($tryId in $attemptIds) {
    $wingetArgs = $baseArgs.Clone()
    $wingetArgs[4] = $tryId  # replace the id in-place

    if ($PSCmdlet.ShouldProcess($Name, "winget $($wingetArgs -join ' ')")) {
      Write-Information "Installing $Name ($tryId)."
      $proc = Start-Process -FilePath $Winget -ArgumentList $wingetArgs -NoNewWindow -PassThru -Wait

      switch ($proc.ExitCode) {
        0               { return }  # success
        -1978335212     { Write-Verbose "Package not found for ${Name} ($tryId). Trying fallback (if any)..." } # no package found
        -2147024891     { throw "Access denied installing $Name ($tryId). Try an elevated session or disable AllUsers." } # 0x80070005
        Default         { Write-Verbose "winget exit code for ${Name}: $($proc.ExitCode)"; throw "Failed to install $Name ($tryId)" }
      }
    }
  }
  throw "Failed to install $Name after trying: $($attemptIds -join ', ')"
}

function Test-CommandAvailable {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$CommandName)
  $cmd = Get-Command -Name $CommandName -ErrorAction SilentlyContinue
  return [bool]$cmd
}

# --- Essentials ---
$packages = @(
  @{ Id = 'Git.Git';                   Name = 'Git';             Cmd = 'git' }
  @{ Id = 'Neovim.Neovim';             Name = 'Neovim';          Cmd = 'nvim' }
  @{ Id = 'GNU.Nano';                  Name = 'GNU Nano';        Cmd = 'nano' }
  @{ Id = 'Fastfetch-cli.Fastfetch';   Name = 'Fastfetch CLI';   Cmd = 'fastfetch' }   # fixed ID
  @{ Id = 'Ookla.Speedtest.CLI';       Name = 'Speedtest CLI';   Cmd = 'speedtest' }   # fixed ID
  @{ Id = 'GnuWin32.Make';             Name = 'make (GnuWin32)'; Cmd = 'make' }
)

# --- Optional extras ---
if ($IncludeOptional) {
  $packages += @(
    @{ Id = '7zip.7zip';               Name = '7-Zip';           Cmd = '7z' }
    @{ Id = 'JanDeDobbeleer.OhMyPosh'; Name = 'Oh My Posh';      Cmd = 'oh-my-posh' }
  )
}

# --- Heal sources, then install ---
Initialize-WingetSource

foreach ($p in $packages) {
  try {
    Install-WingetPackage -Id $p.Id -Name $p.Name -AllUsersParam:$AllUsers
  } catch {
    Write-Information "Skipping $($p.Name): $($_.Exception.Message)"
  }
}

# --- Refresh PATH for current session ---
$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
            [Environment]::GetEnvironmentVariable("Path","User")

# --- Common install directories fallback (session only) ---
$possibleDirs = @(
  "C:\Program Files\fastfetch",
  "C:\Program Files\Ookla\Speedtest CLI",
  "C:\Program Files (x86)\GnuWin32\bin"
)
foreach ($d in $possibleDirs) {
  if ((Test-Path -LiteralPath $d) -and ($env:Path -notmatch [Regex]::Escape($d))) {
    $env:Path += ";$d"
  }
}

# --- Verify availability ---
Write-Information "Verifying installed commands."
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

