# optimize-wsl-vhd.ps1

# Cleans WSL ext4 VHD's for bloat on Windows
# Run this PowerShell script as Administrator
# By default it creates a backup ext4.vhx filesystem
# Run .\optimize-wsl-vhd.ps1 -nb or -noBackup flag 
# to skip generating a backup.

param (
    [Alias("nb")]
    [switch]$noBackup
)

$logFile = "optimize-wsl-vhd.log"
Start-Transcript -Path $logFile -Append

Write-Host "`n?? Scanning known locations for ext4.vhdx files..." -ForegroundColor Cyan

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
    Write-Host "? No ext4.vhdx files found in known WSL paths." -ForegroundColor Red
    Stop-Transcript
    exit 1
}

Write-Host "`n?? Found ext4.vhdx files:" -ForegroundColor Yellow
$vhds | ForEach-Object { Write-Host "[$($_.Index)] $($_.FullName) - $($_.SizeGB) GB" }

$choice = Read-Host "`nEnter the number of the VHD you want to optimize"
$selected = $vhds | Where-Object { $_.Index -eq [int]$choice }

if (-not $selected) {
    Write-Host "? Invalid selection. Exiting." -ForegroundColor Red
    Stop-Transcript
    exit 1
}

$fullPath = $selected.FullName
$folder = Split-Path $fullPath
$backupPath = Join-Path $folder "ext4-backup.vhdx"

Write-Host "`n?? Selected VHD:" -ForegroundColor Cyan
Write-Host $fullPath
Write-Host "?? Size before: $($selected.SizeGB) GB"

# Shutdown WSL
Write-Host "`n? Shutting down WSL..."
wsl --shutdown
Start-Sleep -Seconds 2

# Optional Backup
if (-not $noBackup.IsPresent) {
    Write-Host "`n?? Creating backup: $backupPath"
    Copy-Item -Path $fullPath -Destination $backupPath -Force
} else {
    Write-Host "`n?? Skipping backup (you used -noBackup or -nb)" -ForegroundColor DarkYellow
}

# Optimize
Write-Host "`n?? Optimizing with Optimize-VHD..."
Optimize-VHD -Path $fullPath -Mode Full

# Size after
$sizeAfter = (Get-Item $fullPath).Length / 1GB
$delta = [math]::Round($selected.SizeGB - $sizeAfter, 2)

Write-Host "`n? Done!" -ForegroundColor Green
Write-Host "?? Size after optimization: $([math]::Round($sizeAfter,2)) GB"
Write-Host "?? Space saved: $delta GB" -ForegroundColor Green

Write-Host "`n?? Log saved to: $logFile"
if (-not $noBackup.IsPresent) {
    Write-Host "?? Backup saved to: $backupPath"
}
Write-Host "`n?? You can now restart WSL using 'wsl'" -ForegroundColor Cyan

Stop-Transcript
