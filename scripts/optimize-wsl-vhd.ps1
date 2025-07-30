# optimize-wsl-vhd.ps1
<#
.SYNOPSIS
  Optimize WSL2 VHDX Linux files/filesystems and optionally back them up.

.DESCRIPTION
  This script finds all ext4.vhdx files related to WSL2 Linux distributions and
  compacts them using Optimize-VHD to reclaim disk space. By default, it
  creates a backup of the VHDX before shrinking it unless a -noBackup
  (or -nb) flag is passed.

.PARAMETER noBackup
  Skip creation of the ext4-backup.vhdx file before optimization.

.EXAMPLE
  PS> ./optimize-wsl-vhd.ps1
  Prompts for a WSL disk and creates a backup before shrinking it.

  PS> ./optimize-wsl-vhd.ps1 -noBackup
  Prompts for a WSL disk and shrinks it without creating a backup.

.NOTES
  Created: 2025-07-30
  Author: rcghpge (https://github.com/rcghpge)
  License: MIT — https://opensource.org/licenses/MIT
  Version: 0.1.0
  Repository: https://github.com/rcghpge/dotfiles
#>

[CmdletBinding()]
param (
    [Alias("nb")]
    [switch]$noBackup
)

$logFile = "optimize-wsl-vhd.log"
Start-Transcript -Path $logFile -Append

Write-Output "`n[INFO] Scanning known locations for ext4.vhdx files..."

$searchPaths = @(
  "$env:LOCALAPPDATA\wsl",
  "$env:LOCALAPPDATA\Packages",
  "D:\wsl",
  "E:\wsl"
)

$vhds = @()
$i = 0

foreach ($path in $searchPaths) {
  if (Test-Path $path) {
    Get-ChildItem -Path $path -Filter ext4.vhdx -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
      $vhds += [PSCustomObject]@{
        Index = $i
        FullName = $_.FullName
        SizeGB = "{0:N2}" -f ($_.Length / 1GB)
      }
      $i++
    }
  }
}

if (-not $vhds -or $vhds.Count -eq 0) {
    Write-Error "[ERROR] No ext4.vhdx files found in known WSL paths."
    Stop-Transcript
    exit 1
}

Write-Output "`n[INFO] Found ext4.vhdx files:"
$vhds | ForEach-Object { Write-Output "[$($_.Index)] $($_.FullName) - $($_.SizeGB) GB" }

$choice = Read-Host "`nEnter the number of the VHD you want to optimize"
$selected = $vhds | Where-Object { $_.Index -eq [int]$choice }

if (-not $selected) {
    Write-Error "[ERROR] Invalid selection. Exiting."
    Stop-Transcript
    exit 1
}

$fullPath = $selected.FullName
$folder = Split-Path $fullPath
$backupPath = Join-Path $folder "ext4-backup.vhdx"

Write-Output "`n[INFO] Selected VHD:"
Write-Output "$fullPath"
Write-Output "[INFO] Size before: $($selected.SizeGB) GB"

Write-Output "`n[INFO] Shutting down WSL..."
wsl --shutdown
Start-Sleep -Seconds 2

if (-not $noBackup.IsPresent) {
    Write-Output "`n[INFO] Creating backup: $backupPath"
    Copy-Item -Path $fullPath -Destination $backupPath -Force
} else {
    Write-Warning "[WARN] Skipping backup (you used -noBackup or -nb)"
}

Write-Output "`n[INFO] Optimizing with Optimize-VHD..."
Optimize-VHD -Path $fullPath -Mode Full

$sizeAfter = (Get-Item $fullPath).Length / 1GB
$delta = [math]::Round($selected.SizeGB - $sizeAfter, 2)

Write-Output "`n[INFO] Done!"
Write-Output "[INFO] Size after optimization: $([math]::Round($sizeAfter,2)) GB"
Write-Output "[INFO] Space saved: $delta GB"

Write-Output "`n[INFO] Log saved to: $logFile"
if (-not $noBackup.IsPresent) {
    Write-Output "[INFO] Backup saved to: $backupPath"
}
Write-Output "`n[INFO] You can now restart WSL using 'wsl'"

Stop-Transcript

