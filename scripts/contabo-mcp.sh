#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v npx >/dev/null 2>&1; then
  echo "npx not found in PATH. Install Node.js/npm first." >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "node not found in PATH. Install Node.js first." >&2
  exit 1
fi

if [[ -z "${CONTABO_MCP_API_KEY:-}" ]]; then
  if [[ -f "${VPS_PROFILES_PATH:-$ROOT_DIR/profiles.json}" ]]; then
    eval "$(
      node "$ROOT_DIR/scripts/profiles.js" resolve --provider contabo --format shell
    )"
  fi
fi

CONTABO_MCP_URL="${CONTABO_MCP_URL:-https://contabo.run.mcp.com.ai/mcp}"
CONTABO_MCP_TRANSPORT="${CONTABO_MCP_TRANSPORT:-http-only}"

contabo_api_key="${CONTABO_MCP_API_KEY:-}"

if [[ -z "$contabo_api_key" ]]; then
  echo "Missing Contabo MCP connector key. Configure CONTABO_MCP_API_KEY in the environment or selected contabo profile. For the official Contabo REST API path, use scripts/contabo-api.js with CLIENT_ID/CLIENT_SECRET/API_USER/API_PASSWORD or CONTABO_ACCESS_TOKEN." >&2
  exit 1
fi

# Keep credential out of process args and suppress mcp-remote stderr logs by default.
export CONTABO_RUNTIME_API_KEY="$contabo_api_key"

exec npx -y mcp-remote@latest \
  "$CONTABO_MCP_URL" \
  --transport "$CONTABO_MCP_TRANSPORT" \
  --silent \
  --header 'X-API-Key: ${CONTABO_RUNTIME_API_KEY}' \
  "$@"
