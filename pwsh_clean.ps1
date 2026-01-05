<#
.SYNOPSIS
  Clean up pwsh session: Removes custom aliases('ls'), modules, vars, history. Auto-creates profile if missing.
  Use -DiskCleanup (admin) for temps. Run without profile first.

.DESCRIPTION
  Resets vanilla pwsh in current Terminal tab/window.

.PARAMETER ConfirmCleanup
  Prompt before clean.

.PARAMETER DiskCleanup
  Clean %TEMP%/Win\Temp (admin).

.EXAMPLE
  .\pwsh_clean.ps1
  pwsh -File pwsh_clean.ps1

.NOTES
  Created: 2026-01-05
  Author: rcghpge (https://github.com/rcghpge)
  License: MIT - https://opensource.org/licenses/MIT
  Version: 0.1.1  # PSScriptAnalyzer clean
  Repository: https://github.com/rcghpge/dotfiles
  Upgrade PowerShell env: winget install --id Microsoft.PowerShell --source winget
  Quick Restart: pwsh -NoExit 
#>

[CmdletBinding()]
param([switch]$ConfirmCleanup, [switch]$DiskCleanup)

Write-Information "Cleaning pwsh session..." -InformationAction Continue

if ($ConfirmCleanup) {
  $title = "pwsh_clean"
  $msg = "Removes 'ls'/customs. Continue? (y/N)"
  $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes"
  $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No"
  $choices = @($yes, $no)
  $result = $host.ui.PromptForChoice($title, $msg, $choices, 1)
  if ($result -eq 1) { 
    Write-Warning "Aborted."
    return 
  }
}

# Variables: Remove non-built-in
$StartupVars = (Get-Variable).Name
Get-Variable | Where-Object { $_.Name -notin $StartupVars -and $_.Options -notmatch 'ReadOnly|Constant' } |
  Remove-Variable -Force -Scope Global -ErrorAction SilentlyContinue

# Modules: Remove non-core
$coreModules = @('Microsoft.PowerShell.*', 'PSDesiredConfiguration')
Get-Module | Where-Object { $coreModules -notcontains $_.Name } |
  Remove-Module -Force -ErrorAction SilentlyContinue

# Aliases: Remove non-constant (removes 'ls' etc.)
Get-Alias | Where-Object { $_.Options -ne 'Constant' } |
  Remove-Alias -Force -ErrorAction SilentlyContinue

# Functions: Remove user-defined
Get-ChildItem Function:\ | Where-Object ModuleName -eq '' |
  Remove-Item -Force -ErrorAction SilentlyContinue

# History & Sessions
Clear-History
Get-PSSession | Remove-PSSession -ErrorAction SilentlyContinue

# Disk Temp Cleanup
if ($DiskCleanup) {
  if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Disk cleanup requires Administrator."
  } else {
    Write-Information "Cleaning temp folders..." -InformationAction Continue
    $tempPaths = @("$env:TEMP", "$env:SystemRoot\Temp")
    foreach ($path in $tempPaths) {
      if (Test-Path $path) {
        Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
          Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        Write-Information "  $path cleaned" -InformationAction Continue
      }
    }
  }
}

Write-Information "pwsh_clean Complete!" -InformationAction Continue

# Profile Detection + Auto-Create
$profilePath = $PROFILE.CurrentUserCurrentHost
if (-not (Test-Path $profilePath)) {
  Write-Warning "Profile missing: $profilePath"
  $create = Read-Host "Create with 'ls', 'cat', 'Reload-Profile'? (Y/n)"
  if ($create -notin @('n','N','no','No')) {
    $profileDir = Split-Path $profilePath
    New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
    $profileContent = @'
# pwsh profile - created by pwsh_clean.ps1 (rcghpge/dotfiles)
Set-Alias ls       Get-ChildItem  -Scope Global -Option AllScope
Set-Alias cat      Get-Content    -Scope Global -Option AllScope
Set-Alias which    Get-Command    -Scope Global -Option AllScope
function Reload-Profile { . $PROFILE.CurrentUserCurrentHost }
'@
    Set-Content -Path $profilePath -Value $profileContent -Encoding UTF8
    . $profilePath
    Write-Information "Profile created & loaded!" -InformationAction Continue
  } else {
    Write-Information "Manual: New-Item '$profilePath' -ItemType File -Force; . `$PROFILE" -InformationAction Continue
  }
} else {
  Write-Information "Profile ready. Reload: . `$PROFILE" -InformationAction Continue
}

