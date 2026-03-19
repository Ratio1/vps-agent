#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
PROFILES_FILE="${VPS_PROFILES_PATH:-$ROOT_DIR/profiles.json}"
case "$PROFILES_FILE" in
  "$ROOT_DIR"/*)
    PROFILES_LABEL="${PROFILES_FILE#$ROOT_DIR/}"
    ;;
  *)
    PROFILES_LABEL="$PROFILES_FILE"
    ;;
esac

ok() { echo "[ok] $1"; }
warn() { echo "[warn] $1"; }
fail() { echo "[fail] $1"; exit 1; }

command -v node >/dev/null 2>&1 && ok "node: $(node -v)" || fail "node missing"
command -v npm >/dev/null 2>&1 && ok "npm: $(npm -v)" || fail "npm missing"
command -v npx >/dev/null 2>&1 && ok "npx available" || fail "npx missing"
command -v codex >/dev/null 2>&1 && ok "codex installed" || fail "codex missing"
command -v hostinger-api-mcp >/dev/null 2>&1 && ok "hostinger-api-mcp installed" || fail "hostinger-api-mcp missing"

if [[ -f "$PROFILES_FILE" ]]; then
  ok "${PROFILES_LABEL} present"
  if profiles_report="$(node scripts/profiles.js validate --file "$PROFILES_FILE" --format json 2>/dev/null)"; then
    ok "${PROFILES_LABEL} parsed successfully"
    tenant_count="$(printf '%s' "$profiles_report" | node -e 'const fs=require("fs"); const data=JSON.parse(fs.readFileSync(0,"utf8")); process.stdout.write(String(data.tenants));')"
    account_count="$(printf '%s' "$profiles_report" | node -e 'const fs=require("fs"); const data=JSON.parse(fs.readFileSync(0,"utf8")); process.stdout.write(String(data.accounts.length));')"
    warning_count="$(printf '%s' "$profiles_report" | node -e 'const fs=require("fs"); const data=JSON.parse(fs.readFileSync(0,"utf8")); process.stdout.write(String(data.warnings.length));')"
    hostinger_count="$(node scripts/profiles.js list --file "$PROFILES_FILE" --provider hostinger --format json --optional | node -e 'const fs=require("fs"); const data=JSON.parse(fs.readFileSync(0,"utf8")); process.stdout.write(String(data.length));')"
    contabo_count="$(node scripts/profiles.js list --file "$PROFILES_FILE" --provider contabo --format json --optional | node -e 'const fs=require("fs"); const data=JSON.parse(fs.readFileSync(0,"utf8")); process.stdout.write(String(data.length));')"
    ok "${PROFILES_LABEL} summary: ${tenant_count} tenants, ${account_count} accounts"
    if [[ "$warning_count" -gt 0 ]]; then
      while IFS= read -r validation_warning; do
        warn "$validation_warning"
      done < <(printf '%s' "$profiles_report" | node -e 'const fs=require("fs"); const data=JSON.parse(fs.readFileSync(0,"utf8")); for (const warning of data.warnings) console.log(warning);')
    fi
    if [[ "$hostinger_count" -gt 0 ]]; then
      ok "Hostinger account(s) configured in ${PROFILES_LABEL}: ${hostinger_count}"
    else
      warn "No hostinger accounts configured in ${PROFILES_LABEL}"
    fi
    if [[ "$contabo_count" -gt 0 ]]; then
      ok "Contabo account(s) configured in ${PROFILES_LABEL}: ${contabo_count}"
    else
      warn "No contabo accounts configured in ${PROFILES_LABEL}"
    fi
  else
    fail "${PROFILES_LABEL} is invalid"
  fi
else
  warn "${PROFILES_LABEL} does not exist"
fi

if [[ -f scripts/contabo-mcp.sh ]]; then
  ok "scripts/contabo-mcp.sh present"
else
  warn "scripts/contabo-mcp.sh missing"
fi

if [[ -f .codex/config.toml ]]; then
  ok ".codex/config.toml present"
  if grep -q '^\[agents\]' .codex/config.toml; then
    ok "[agents] section present in .codex/config.toml"
  else
    warn "[agents] section missing from .codex/config.toml"
  fi
  if grep -q '^\[mcp_servers\.openaiDeveloperDocs\]' .codex/config.toml; then
    ok "OpenAI Docs MCP configured in .codex/config.toml"
  else
    warn "OpenAI Docs MCP missing from .codex/config.toml"
  fi
else
  warn ".codex/config.toml missing"
fi

required_codex_agents=(
  "ops-explorer.toml"
  "ops-builder.toml"
  "ops-critic.toml"
  "ops-verifier.toml"
  "docs-researcher.toml"
)

if [[ -d .codex/agents ]]; then
  ok ".codex/agents present"
  for agent_file in "${required_codex_agents[@]}"; do
    if [[ -f ".codex/agents/${agent_file}" ]]; then
      ok ".codex/agents/${agent_file} present"
    else
      warn ".codex/agents/${agent_file} missing"
    fi
  done
else
  warn ".codex/agents missing"
fi
