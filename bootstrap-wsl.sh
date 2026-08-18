#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="${HOME}/server_setup"
repo_name="highTowerSU/server_setup"

if ! grep -qi microsoft /proc/version 2>/dev/null; then
  echo "Dieses Skript ist für WSL gedacht." >&2
  exit 1
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
ansible-playbook -i inventory/wsl.yml playbooks/guests.yml
