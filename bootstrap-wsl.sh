#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="${HOME}/server_setup"
repo_name="highTowerSU/server_setup"
is_wsl=false
input_device=/dev/stdin
vaultwarden_session_active=false

lock_vaultwarden() {
  if [[ "${vaultwarden_session_active}" == true ]] && command -v bw >/dev/null 2>&1; then
    bw lock >/dev/null 2>&1 || true
  fi
}
trap lock_vaultwarden EXIT

if [[ "${EUID}" -eq 0 ]]; then
  sudo_cmd=()
else
  sudo_cmd=(sudo)
fi
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

if grep -qi microsoft /proc/version 2>/dev/null; then
  is_wsl=true
fi

if [[ -r /dev/tty && -t /dev/tty ]]; then
  input_device=/dev/tty
fi

"${sudo_cmd[@]}" apt-get update
"${sudo_cmd[@]}" apt-get install -y \
  git \
  gh \
  python3 \
  python3-venv \
  pipx \
  openssh-client \
  ca-certificates \
  curl

if ! command -v bw >/dev/null 2>&1; then
  bw_url="$(curl -fsSL 'https://api.github.com/repos/bitwarden/clients/releases?per_page=20' | python3 -c 'import json,sys; releases=json.load(sys.stdin); print(next(asset["browser_download_url"] for release in releases if release.get("tag_name", "").startswith("cli-") for asset in release.get("assets", []) if asset["name"].startswith("bw-linux-") and asset["name"].endswith(".zip")))')"
  tmp_dir="$(mktemp -d)"
  trap 'lock_vaultwarden; rm -rf "${tmp_dir}"' EXIT
  curl -fsSL "${bw_url}" -o "${tmp_dir}/bw.zip"
  python3 -c 'import sys,zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "${tmp_dir}/bw.zip" "${tmp_dir}"
  "${sudo_cmd[@]}" install -m 0755 "${tmp_dir}/bw" /usr/local/bin/bw
fi

if command -v bw >/dev/null 2>&1 && ! bw status 2>/dev/null | grep -q '"status":"unlocked"'; then
  echo
  echo "Vaultwarden/Bitwarden wird für SSH-Authorized-Keys benötigt."
  while true; do
    vaultwarden_url="${VAULTWARDEN_URL:-https://pass.koenigsbl.au}"
    vaultwarden_user="${VAULTWARDEN_USER:-server-setup@koenigsbl.au}"
    read -r -p "Vaultwarden-Server-URL [${vaultwarden_url}]: " vaultwarden_override <"${input_device}"
    if [[ -n "${vaultwarden_override}" ]]; then
      vaultwarden_url="${vaultwarden_override}"
    fi
    echo "Vaultwarden-URL: ${vaultwarden_url}"
    bw_status="$(bw status 2>/dev/null || true)"
    if printf '%s' "${bw_status}" | grep -Eq '"status"[[:space:]]*:[[:space:]]*"(locked|unlocked)"'; then
      if BW_SESSION="$(bw unlock --raw <"${input_device}")"; then
        break
      fi
    else
      if ! bw config server "${vaultwarden_url}"; then
        echo "Vaultwarden-Server konnte nicht konfiguriert werden. Bitte zuerst mit 'bw logout' abmelden."
        continue
      fi
      if BW_SESSION="$(bw login "${vaultwarden_user}" --raw <"${input_device}")"; then
        break
      fi
    fi
    echo "Vaultwarden-Anmeldung/Unlock fehlgeschlagen. Bitte erneut versuchen."
  done
  export BW_SESSION
  vaultwarden_session_active=true

  github_vaultwarden_item="${GITHUB_VAULTWARDEN_ITEM:-github-server-setup-token}"
  github_token="$(bw get password "${github_vaultwarden_item}" --session "${BW_SESSION}" 2>/dev/null || true)"
  if [[ -n "${github_token}" ]]; then
    export GH_TOKEN="${github_token}"
  fi
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "GitHub-Anmeldung erforderlich."
  if [[ -n "${GH_TOKEN:-}" ]]; then
    printf '%s\n' "${GH_TOKEN}" | gh auth login --with-token --git-protocol https
    unset GH_TOKEN
  else
    gh auth login --git-protocol https <"${input_device}"
  fi
fi
gh config set git_protocol https

if [[ -e "${repo_dir}" && ! -d "${repo_dir}/.git" ]]; then
  echo "${repo_dir} existiert bereits, ist aber kein Git-Repository." >&2
  exit 1
fi

if [[ -d "${repo_dir}/.git" ]]; then
  git -C "${repo_dir}" remote set-url origin "https://github.com/${repo_name}.git"
  git -C "${repo_dir}" pull --ff-only
else
  gh auth setup-git
  git clone "https://github.com/${repo_name}.git" "${repo_dir}"
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
  ansible-playbook --ask-become-pass -i inventory/wsl.yml playbooks/wsl.yml <"${input_device}"
else
  inventory_file="$(mktemp --suffix=.yml)"
  cleanup_inventory() {
    rm -f "${inventory_file}"
  }
  trap 'lock_vaultwarden; cleanup_inventory' EXIT
  cat >"${inventory_file}" <<'YAML'
all:
  children:
    guests:
      children:
        lxc_guests:
          hosts:
            lxc_local:
              ansible_connection: local
YAML
  if [[ "${EUID}" -eq 0 ]]; then
    ansible-playbook -i "${inventory_file}" playbooks/guests.yml
  else
    ansible-playbook --ask-become-pass -i "${inventory_file}" playbooks/guests.yml
  fi
fi
