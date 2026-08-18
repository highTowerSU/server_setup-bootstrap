# WSL Bootstrap

Installiert Debian unter WSL und startet darin den Linux-Bootstrap für
`highTowerSU/server_setup`.

PowerShell:

```powershell
irm https://raw.githubusercontent.com/highTowerSU/server_setup-bootstrap/main/bootstrap-wsl.ps1 | iex
```

`cmd.exe`:

```bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/highTowerSU/server_setup-bootstrap/main/bootstrap-wsl.ps1 | iex"
```

Alternativ können `bootstrap-wsl.ps1` oder `bootstrap-wsl.cmd` heruntergeladen
und lokal gestartet werden. Für die erstmalige WSL-Installation können
Administratorrechte und ein Windows-Neustart erforderlich sein.
