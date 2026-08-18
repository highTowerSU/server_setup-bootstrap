# WSL Bootstrap

Installiert Debian unter WSL und startet darin den Linux-Bootstrap für
`highTowerSU/server_setup`.

PowerShell:

```powershell
irm https://raw.githubusercontent.com/highTowerSU/server_setup-bootstrap/main/bootstrap-wsl.ps1 | iex
```

Falls die Pipeline-Ausführung durch eine Unternehmensrichtlinie blockiert
wird, stattdessen aus `cmd.exe` mit einer temporären Datei starten:

```bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p=Join-Path $env:TEMP 'bootstrap-wsl.ps1'; Invoke-WebRequest -UseBasicParsing https://raw.githubusercontent.com/highTowerSU/server_setup-bootstrap/main/bootstrap-wsl.ps1 -OutFile $p; powershell.exe -NoProfile -ExecutionPolicy Bypass -File $p"
```

`cmd.exe`:

```bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/highTowerSU/server_setup-bootstrap/main/bootstrap-wsl.ps1 | iex"
```

Alternativ können `bootstrap-wsl.ps1` oder `bootstrap-wsl.cmd` heruntergeladen
und lokal gestartet werden. Für die erstmalige WSL-Installation können
Administratorrechte und ein Windows-Neustart erforderlich sein.

Optional kann das Vaultwarden-Item `github-server-setup-token` ein GitHub
Fine-Grained-Token im Passwortfeld enthalten. Das Token sollte nur Zugriff auf
`server_setup` mit `Contents: Read-only` erhalten. Ein anderer Itemname kann
über `GITHUB_VAULTWARDEN_ITEM` gesetzt werden.
