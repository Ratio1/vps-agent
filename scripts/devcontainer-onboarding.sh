#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

info() { echo "[info] $1"; }
ok() { echo "[ok] $1"; }
warn() { echo "[warn] $1"; }
fail() { echo "[fail] $1"; exit 1; }

is_tty() {
  [[ -t 0 && -t 1 ]]
}

ensure_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    touch "$path"
  fi
}

install_bashrc_autostart_hook() {
  local bashrc_path="$HOME/.bashrc"
  local hook_start="# >>> VPS Agent codex autostart >>>"
  local hook_end="# <<< VPS Agent codex autostart <<<"

  ensure_file "$bashrc_path"

  local tmp
  tmp=$(mktemp)

  awk -v start="$hook_start" -v end="$hook_end" '
    # Remove any prior Codex autostart block before appending the current one.
    $0 ~ /^# >>> .* codex autostart >>>$/ { in_block = 1; next }
    $0 ~ /^# <<< .* codex autostart <<<$/ { in_block = 0; next }
    !in_block { print }
  ' "$bashrc_path" > "$tmp"

  cat >> "$tmp" <<EOF

$hook_start
if [[ -n "\${DEVCONTAINER:-}" || "\${REMOTE_CONTAINERS:-}" == "true" ]] && [[ -t 0 && -t 1 ]]; then
  _vps_agent_root="$ROOT_DIR"
  _vps_agent_marker="/tmp/vps-agent-codex-autostart.\${USER:-node}"
  _vps_agent_auto_start="\${AUTO_START_CODEX:-true}"
  _vps_agent_auto_start="\$(echo "\$_vps_agent_auto_start" | tr '[:upper:]' '[:lower:]')"
  if [[ "\$_vps_agent_auto_start" =~ ^(1|true|yes|y)$ ]] && [[ -f "\$_vps_agent_root/scripts/devcontainer-onboarding.sh" ]]; then
    if [[ "\$PWD" == "\$_vps_agent_root" || "\$PWD" == "\$_vps_agent_root/"* ]]; then
      if [[ ! -f "\$_vps_agent_marker" ]]; then
        if bash "\$_vps_agent_root/scripts/devcontainer-onboarding.sh"; then
          touch "\$_vps_agent_marker" 2>/dev/null || true
        fi
      fi
    fi
  fi
  unset _vps_agent_root _vps_agent_marker _vps_agent_auto_start
fi
$hook_end
EOF

  mv "$tmp" "$bashrc_path"
}

if [[ ! -f profiles.json && -f profiles.json.template ]]; then
  cp profiles.json.template profiles.json
  info "Created profiles.json from profiles.json.template"
fi

if ! command -v codex >/dev/null 2>&1; then
  fail "codex is missing in the devcontainer"
fi

if ! command -v hostinger-api-mcp >/dev/null 2>&1; then
  fail "hostinger-api-mcp is missing in the devcontainer"
fi

install_bashrc_autostart_hook

CODEX_STATUS="$(codex login status 2>&1 || true)"
if echo "$CODEX_STATUS" | grep -qi "logged in"; then
  ok "Codex authentication already configured"
else
  warn "Codex is not logged in"

  if is_tty; then
    echo "Choose Codex login method:"
    echo "1) ChatGPT login (recommended)"
    echo "2) API key login"
    printf "Enter choice [1/2]: "
    read -r choice

    case "$choice" in
      2)
        printf "Paste your OPENAI_API_KEY (input hidden): "
        read -r -s openai_key
        echo
        if [[ -z "$openai_key" ]]; then
          fail "OPENAI_API_KEY cannot be empty"
        fi
        printf "%s\n" "$openai_key" | codex login --with-api-key
        ok "Configured Codex API-key login"
        ;;
      *)
        codex login
        ;;
    esac
  else
    warn "No interactive terminal. Run this in the container terminal:"
    warn "bash scripts/devcontainer-onboarding.sh"
    exit 0
  fi
fi

profiles_overview="$(node scripts/profiles.js list --format text --optional 2>/dev/null || true)"
selected_hostinger_token="$(
  node scripts/profiles.js resolve --provider hostinger --format json --optional 2>/dev/null \
    | node -e 'const fs=require("fs"); const raw=fs.readFileSync(0,"utf8").trim(); if (!raw) process.exit(0); const data=JSON.parse(raw); const env=data.env || {}; process.stdout.write(String(env.API_TOKEN || env.HOSTINGER_API_TOKEN || "").trim());' \
    2>/dev/null || true
)"

if [[ -n "$profiles_overview" && "$profiles_overview" != "No accounts configured." ]]; then
  ok "profiles.json already contains account entries"
  printf "%s\n" "$profiles_overview"
else
  warn "profiles.json does not contain any configured accounts yet"
fi

if is_tty; then
  configure_hostinger="y"
  if [[ -n "$selected_hostinger_token" ]]; then
    ok "The selected Hostinger account already has a token"
    printf "Add or update a default Hostinger account now? [y/N]: "
    read -r configure_hostinger
    configure_hostinger="$(echo "${configure_hostinger:-n}" | tr '[:upper:]' '[:lower:]')"
  elif [[ -n "$profiles_overview" && "$profiles_overview" != "No accounts configured." ]]; then
    warn "The selected Hostinger account is missing a usable token"
  fi

  if [[ "$configure_hostinger" =~ ^(y|yes)$ ]] || [[ -z "$selected_hostinger_token" ]]; then
    printf "Tenant name [customer-a]: "
    read -r tenant_name
    tenant_name="${tenant_name:-customer-a}"

    printf "Hostinger account name [primary]: "
    read -r hostinger_account
    hostinger_account="${hostinger_account:-primary}"

    printf "Paste your HOSTINGER_API_TOKEN (input hidden): "
    read -r -s hostinger_token
    echo
    if [[ -z "$hostinger_token" ]]; then
      fail "HOSTINGER_API_TOKEN cannot be empty"
    fi

    node scripts/profiles.js upsert-account \
      --tenant "$tenant_name" \
      --provider hostinger \
      --account "$hostinger_account" \
      --credential "API_TOKEN=$hostinger_token" \
      --setting "HOSTINGER_MCP_DEBUG=false" \
      --make-default >/dev/null

    ok "Saved default Hostinger account in profiles.json"
  fi
else
  warn "profiles.json must be updated manually in a terminal session"
  warn "Run in container terminal: bash scripts/devcontainer-onboarding.sh"
  exit 0
fi

if [[ ! -f .codex/config.toml ]]; then
  mkdir -p .codex
  cp .codex/config.toml.example .codex/config.toml
  ok "Created .codex/config.toml"
fi

bash scripts/doctor-unix.sh

AUTO_START_CODEX_VALUE="${AUTO_START_CODEX:-true}"
AUTO_START_CODEX_VALUE="$(echo "$AUTO_START_CODEX_VALUE" | tr '[:upper:]' '[:lower:]')"

if [[ "$AUTO_START_CODEX_VALUE" =~ ^(1|true|yes|y)$ ]]; then
  if is_tty; then
    info "Starting Codex automatically..."
    exec bash scripts/start-agent.sh --auto
  fi

  warn "AUTO_START_CODEX is enabled but terminal is non-interactive."
  warn "Start manually with: bash scripts/start-agent.sh"
  exit 0
fi

echo
echo "Ready. Start Codex with: bash scripts/start-agent.sh"
