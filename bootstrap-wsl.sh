#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="${HOME}/server_setup"
repo_name="highTowerSU/server_setup"
is_wsl=false

if grep -qi microsoft /proc/version 2>/dev/null; then
  is_wsl=true
fi

sudo apt-get update
sudo apt-get install -y \
  git \
  gh \
  python3 \
  python3-venv \
  pipx \
  openssh-client \
  ca-certificates

if ! command -v bw >/dev/null 2>&1; then
  sudo apt-get install -y nodejs npm
  sudo npm install --global @bitwarden/cli
fi

if command -v bw >/dev/null 2>&1 && ! bw status 2>/dev/null | grep -q '"status":"unlocked"'; then
  echo
  echo "Vaultwarden/Bitwarden wird für SSH-Authorized-Keys benötigt."
  read -r -p "Vaultwarden-Server-URL (leer für Bitwarden Cloud): " vaultwarden_url </dev/tty
  if [[ -n "${vaultwarden_url}" ]]; then
    bw config server "${vaultwarden_url}"
  fi
  if ! bw status 2>/dev/null | grep -q '"status":"authenticated"'; then
    bw login </dev/tty
  fi
  export BW_SESSION="$(bw unlock --raw </dev/tty)"
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "GitHub-Anmeldung erforderlich."
  gh auth login --git-protocol ssh </dev/tty
fi

if [[ -e "${repo_dir}" && ! -d "${repo_dir}/.git" ]]; then
  echo "${repo_dir} existiert bereits, ist aber kein Git-Repository." >&2
  exit 1
fi

if [[ -d "${repo_dir}/.git" ]]; then
  git -C "${repo_dir}" remote set-url origin "git@github.com:${repo_name}.git"
  git -C "${repo_dir}" pull --ff-only
else
  gh repo clone "${repo_name}" "${repo_dir}"
fi

export PATH="${HOME}/.local/bin:${PATH}"
pipx ensurepath >/dev/null

if ! command -v ansible-playbook >/dev/null 2>&1; then
  pipx install ansible-core
fi
pipx inject ansible-core requests >/dev/null

cd "${repo_dir}"
ansible-galaxy collection install -r requirements.yml

if [[ "${is_wsl}" == true ]]; then
  ansible-playbook --ask-become-pass -i inventory/wsl.yml playbooks/guests.yml </dev/tty
else
  echo
  echo "Ansible ist installiert. Für diesen Server als Nächstes ausführen:"
  echo "  ansible-playbook -i inventory/hosts.yml site.yml --check --diff"
fi
