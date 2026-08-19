param(
    [Alias('d')]
    [switch]$DebugBootstrap
)

$ErrorActionPreference = 'Stop'
$DebugBootstrap = $DebugBootstrap -or ($env:DEBUG_BOOTSTRAP -eq '1')

$Distro = 'Debian'
$LinuxBootstrap = 'https://raw.githubusercontent.com/highTowerSU/server_setup-bootstrap/main/bootstrap-wsl.sh?v=6dfaa1e'
$WindowsBootstrap = 'https://raw.githubusercontent.com/highTowerSU/server_setup-bootstrap/main/bootstrap-wsl.ps1?v=6dfaa1e'
$LinuxUser = $env:USERNAME.ToLower() -replace '[^a-z0-9_-]', '-'
if ($LinuxUser -notmatch '^[a-z_]') { $LinuxUser = "u-$LinuxUser" }
$LinuxUser = $LinuxUser.Substring(0, [Math]::Min($LinuxUser.Length, 32))

function Add-WindowsTerminalZshProfile {
    $settingsCandidates = @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
    )
    $settingsPath = $settingsCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $settingsPath) {
        Write-Host 'Windows Terminal nicht gefunden; Profil wird beim nächsten Start manuell benötigt.'
        return
    }
    $settings = Get-Content -Raw -LiteralPath $settingsPath
    if ($settings -match '"name"\s*:\s*"Debian \(ZSH\)"') {
        Write-Host 'Windows-Terminal-Profil Debian (ZSH) ist bereits vorhanden.'
        return
    }
    $profilesIndex = $settings.IndexOf('"profiles"')
    $listIndex = $settings.IndexOf('"list"', $profilesIndex)
    $arrayIndex = $settings.IndexOf('[', $listIndex)
    if ($profilesIndex -lt 0 -or $listIndex -lt 0 -or $arrayIndex -lt 0) {
        Write-Warning "Windows-Terminal-Konfiguration konnte nicht erweitert werden: $settingsPath"
        return
    }
    $profile = "`r`n      {`r`n        `"name`": `"Debian (ZSH)`",`r`n        `"commandline`": `"wsl.exe -d Debian -u $LinuxUser --cd ~ -e zsh -l`",`r`n        `"startingDirectory`": `"//wsl.localhost/Debian/home/$LinuxUser`"`r`n      },"
    $settings = $settings.Insert($arrayIndex + 1, $profile)
    Set-Content -LiteralPath $settingsPath -Value $settings -Encoding utf8
    Write-Host "Windows-Terminal-Profil Debian (ZSH) angelegt: $settingsPath"
}

Write-Host 'Prüfe WSL und Debian ...'

$statusOutput = @(& wsl.exe --status 2>&1)
if ($statusOutput) {
    Write-Host ($statusOutput -join [Environment]::NewLine)
}
if ($LASTEXITCODE -ne 0) {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $admin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $admin) {
        Write-Host 'Für die erstmalige WSL-Installation werden Administratorrechte benötigt.'
        $command = "Invoke-Expression (Invoke-WebRequest -UseBasicParsing -Uri '$WindowsBootstrap').Content"
        try {
            $elevated = Start-Process powershell.exe -Verb RunAs -PassThru -Wait -ArgumentList @(
                '-NoProfile',
                '-ExecutionPolicy', 'Bypass',
                '-Command', $command
            )
        } catch {
            throw "UAC-Erhöhung konnte nicht gestartet werden: $($_.Exception.Message)"
        }
        exit $elevated.ExitCode
    }
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
    & wsl.exe --install --distribution $Distro --no-launch
    if ($LASTEXITCODE -ne 0) {
        throw "${Distro} konnte nicht installiert werden. Bitte PowerShell als Administrator starten."
    }
}

Add-WindowsTerminalZshProfile

$null = & wsl.exe --distribution $Distro --user root -- getent passwd $LinuxUser 2>$null
if ($LASTEXITCODE -ne 0) {
    $password = Read-Host "Passwort für den Linux-Benutzer ${LinuxUser}" -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
    try {
        $passwordText = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
    Write-Host "Richte Debian-Benutzer ${LinuxUser} ein ..."
    "$LinuxUser`n$passwordText`n$passwordText" | & wsl.exe --distribution $Distro
    if ($LASTEXITCODE -ne 0) {
        throw "Der Debian-Benutzer ${LinuxUser} konnte nicht eingerichtet werden."
    }
}

Write-Host 'Starte den Linux-Bootstrap in Debian ...'
Write-Host "Linux-Bootstrap-URL: $LinuxBootstrap"
$sudoersCommand = "printf '%s\n' '$LinuxUser ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/server-setup-bootstrap; chmod 0440 /etc/sudoers.d/server-setup-bootstrap; apt-get update; apt-get install -y curl ca-certificates"
if ($DebugBootstrap) { Write-Host "DEBUG: wsl.exe -d $Distro -u root -- bash -lc <sudoers/apt command>" }
& wsl.exe --distribution $Distro --user root -- bash -lc $sudoersCommand
if ($LASTEXITCODE -ne 0) {
    throw 'Die Debian-Grundinstallation ist fehlgeschlagen.'
}
if ($DebugBootstrap) { Write-Host "DEBUG: wsl.exe -d $Distro -u root -- curl -H Cache-Control:no-cache -o /tmp/server-setup-bootstrap.sh $LinuxBootstrap" }
& wsl.exe --distribution $Distro --user root -- curl -H 'Cache-Control: no-cache' -H 'Pragma: no-cache' -o /tmp/server-setup-bootstrap.sh $LinuxBootstrap
if ($LASTEXITCODE -ne 0) {
    throw 'Der Linux-Bootstrap konnte nicht heruntergeladen werden.'
}
$runCommand = "bash /tmp/server-setup-bootstrap.sh"
if ($DebugBootstrap) { Write-Host "DEBUG: wsl.exe -d $Distro -u $LinuxUser -- bash -lc <bootstrap>" }
& wsl.exe --distribution $Distro --user $LinuxUser -- bash -lc $runCommand
if ($LASTEXITCODE -ne 0) {
    throw 'Der Linux-Bootstrap ist fehlgeschlagen.'
}
