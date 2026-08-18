$ErrorActionPreference = 'Stop'

$Distro = 'Debian'
$LinuxBootstrap = 'https://raw.githubusercontent.com/highTowerSU/server_setup-bootstrap/main/bootstrap-wsl.sh'

Write-Host 'Prüfe WSL und Debian ...'

$null = & wsl.exe --status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host 'WSL ist noch nicht aktiviert. Installiere WSL und Debian.'
    & wsl.exe --install --distribution $Distro
    if ($LASTEXITCODE -ne 0) {
        throw 'WSL konnte nicht installiert werden. Bitte PowerShell als Administrator starten.'
    }
    Write-Host 'Windows muss möglicherweise neu gestartet werden. Danach dieses Skript erneut ausführen.'
    exit 0
}

$installed = @(& wsl.exe --list --quiet 2>$null | ForEach-Object { $_.Trim() -replace '^\*\s*', '' })
if ($installed -notcontains $Distro) {
    Write-Host "Installiere ${Distro} ..."
    & wsl.exe --install --distribution $Distro
    if ($LASTEXITCODE -ne 0) {
        throw "${Distro} konnte nicht installiert werden. Bitte PowerShell als Administrator starten."
    }
}

Write-Host 'Starte den Linux-Bootstrap in Debian ...'
& wsl.exe --distribution $Distro -- bash -lc "curl -fsSL '$LinuxBootstrap' | bash"
if ($LASTEXITCODE -ne 0) {
    throw 'Der Linux-Bootstrap ist fehlgeschlagen.'
}
