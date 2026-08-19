# WSL Bootstrap

Installiert Debian unter WSL und startet darin den Linux-Bootstrap für
`highTowerSU/server_setup`. Auf Debian-/Ubuntu-LXC-Systemen kann derselbe
Linux-Bootstrap direkt verwendet werden.

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

Kurzer WSL-One-Liner aus `cmd.exe` mit Cache-Buster:

```bat
powershell -nop -ep bypass -c "irm 'https://raw.githubusercontent.com/highTowerSU/server_setup-bootstrap/main/bootstrap-wsl.ps1?v=e075f60'|iex"
```

LXC-One-Liner innerhalb eines Debian-/Ubuntu-LXC:

```sh
f="$(mktemp)"; wget -4 -qO "$f" 'https://raw.githubusercontent.com/highTowerSU/server_setup-bootstrap/main/bootstrap-wsl.sh?v=e075f60' && bash "$f"; r=$?; rm -f "$f"; echo "Bootstrap exit: $r"
```

Der LXC-Aufruf funktioniert als `root` und als normaler Benutzer. Er führt
nach der Grundinstallation das lokale Gäste-Playbook aus. Als `root` ist kein
Become-Passwort erforderlich.

Proxmox wird aus dem privaten Repository auf dem Proxmox-Host gestartet:

```sh
gh repo clone highTowerSU/server_setup /root/server_setup && cd /root/server_setup && bash scripts/proxmox-bootstrap.sh
```

Alternativ können `bootstrap-wsl.ps1` oder `bootstrap-wsl.cmd` heruntergeladen
und lokal gestartet werden. Für die erstmalige WSL-Installation können
Administratorrechte und ein Windows-Neustart erforderlich sein.

Optional kann das Vaultwarden-Item `github-server-setup-token` ein GitHub
Fine-Grained-Token im Passwortfeld enthalten. Das Token sollte nur Zugriff auf
`server_setup` mit `Contents: Read-only` erhalten. Ein anderer Itemname kann
über `GITHUB_VAULTWARDEN_ITEM` gesetzt werden.
