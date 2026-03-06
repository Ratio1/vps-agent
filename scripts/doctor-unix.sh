#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ok() { echo "[ok] $1"; }
warn() { echo "[warn] $1"; }
fail() { echo "[fail] $1"; exit 1; }

command -v node >/dev/null 2>&1 && ok "node: $(node -v)" || fail "node missing"
command -v npm >/dev/null 2>&1 && ok "npm: $(npm -v)" || fail "npm missing"
command -v npx >/dev/null 2>&1 && ok "npx available" || fail "npx missing"
command -v codex >/dev/null 2>&1 && ok "codex installed" || fail "codex missing"
command -v hostinger-api-mcp >/dev/null 2>&1 && ok "hostinger-api-mcp installed" || fail "hostinger-api-mcp missing"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
  if [[ -n "${HOSTINGER_API_TOKEN:-}" ]]; then
    ok "HOSTINGER_API_TOKEN is set"
  else
    warn "HOSTINGER_API_TOKEN is empty in .env"
  fi
else
  warn ".env does not exist"
fi

if [[ -f scripts/contabo-mcp.sh ]]; then
  ok "scripts/contabo-mcp.sh present"
else
  warn "scripts/contabo-mcp.sh missing"
fi

if [[ -n "${CONTABO_MCP_API_KEY:-}" || -n "${CONTABO_ACCESS_TOKEN:-}" ]]; then
  ok "Contabo MCP auth hint appears set"
elif [[ -n "${CONTABO_CLIENT_SECRET:-}" ]]; then
  ok "Contabo client secret appears set (used as Contabo MCP API key)"
elif [[ -n "${CONTABO_CLIENT_ID:-}" ]]; then
  warn "CONTABO_CLIENT_ID is set but no Contabo MCP auth hint found"
fi

if [[ -f .codex/config.toml ]]; then
  ok ".codex/config.toml present"
else
  warn ".codex/config.toml missing"
fi
