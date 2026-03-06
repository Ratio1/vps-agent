#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT_DIR/.env"
  set +a
fi

if ! command -v npx >/dev/null 2>&1; then
  echo "npx not found in PATH. Install Node.js/npm first." >&2
  exit 1
fi

CONTABO_MCP_URL="${CONTABO_MCP_URL:-https://contabo.run.mcp.com.ai/mcp}"
CONTABO_MCP_TRANSPORT="${CONTABO_MCP_TRANSPORT:-http-only}"

contabo_api_key="${CONTABO_MCP_API_KEY:-${CONTABO_ACCESS_TOKEN:-${CONTABO_CLIENT_SECRET:-}}}"

if [[ -z "$contabo_api_key" ]]; then
  echo "Missing Contabo MCP credentials. Set one of CONTABO_MCP_API_KEY, CONTABO_ACCESS_TOKEN, or CONTABO_CLIENT_SECRET in .env." >&2
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
