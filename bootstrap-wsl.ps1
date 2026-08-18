$ErrorActionPreference = 'Stop'

$Distro = 'Debian'
$LinuxBootstrap = 'https://raw.githubusercontent.com/highTowerSU/server_setup-bootstrap/main/bootstrap-wsl.sh'
$WindowsBootstrap = 'https://raw.githubusercontent.com/highTowerSU/server_setup-bootstrap/main/bootstrap-wsl.ps1'
$LinuxUser = $env:USERNAME.ToLower() -replace '[^a-z0-9_-]', '-'
if ($LinuxUser -notmatch '^[a-z_]') { $LinuxUser = "u-$LinuxUser" }
$LinuxUser = $LinuxUser.Substring(0, [Math]::Min($LinuxUser.Length, 32))

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
    "$LinuxUser`n$passwordText`n$passwordText`n" | & wsl.exe --distribution $Distro
    if ($LASTEXITCODE -ne 0) {
        throw "Der Debian-Benutzer ${LinuxUser} konnte nicht eingerichtet werden."
    }
}

Write-Host 'Starte den Linux-Bootstrap in Debian ...'
$bootstrap = (Invoke-WebRequest -UseBasicParsing -Uri $LinuxBootstrap).Content
$bootstrap | & wsl.exe --distribution $Distro -- bash -s
if ($LASTEXITCODE -ne 0) {
    throw 'Der Linux-Bootstrap ist fehlgeschlagen.'
}
