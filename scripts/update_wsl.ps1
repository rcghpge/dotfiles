# Get full list and parse NAME column accurately
$listOutput = wsl --list --verbose
$lines = $listOutput -split "`n" | Where-Object { $_ -match '^\s*[^*]' }

$distros = @()
foreach ($line in $lines) {
    if ($line -match '^\s*(\S.*?)(\s+\*|\s+Stopped|\s+Running|$)') {
        $distros += $matches[1].Trim()
    }
}

foreach ($distroName in $distros) {
    Write-Output "--- Updating $distroName ---"

    # Test by trying a harmless command, capture output
    $testOutput = wsl -d "$distroName" -e bash -c "echo OK" 2>&1
    if ($LASTEXITCODE -ne 0 -or $testOutput -notmatch "OK") {
        Write-Output "Invalid/not running: $distroName"
        continue
    }

    # Update
    wsl -d "$distroName" -u root bash -c "
        export DEBIAN_FRONTEND=noninteractive
        if command -v apt >/dev/null 2>&1; then apt update -qq && apt upgrade -y -qq;
        elif command -v dnf >/dev/null 2>&1; then dnf upgrade -y;
        elif command -v yum >/dev/null 2>&1; then yum update -y;
        elif command -v pacman >/dev/null 2>&1; then pacman -Syu --noconfirm;
        else echo 'Unsupported'; fi
    " 2>&1 | ForEach-Object { if ($_ -notmatch '^Hit:|^Ign:|^Get:|^Need|^Reading|^Building|^0 upgraded|^No') { $_ } }

    Write-Output "Done: $distroName`n"
}
Write-Output "--- Complete ---"

