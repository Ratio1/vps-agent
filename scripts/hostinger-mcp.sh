#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v hostinger-api-mcp >/dev/null 2>&1; then
  echo "hostinger-api-mcp not found in PATH. Install with: npm install -g hostinger-api-mcp" >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "node not found in PATH. Install Node.js first." >&2
  exit 1
fi

if [[ -z "${HOSTINGER_API_TOKEN:-}" && -z "${API_TOKEN:-}" ]]; then
  if [[ -f "${VPS_PROFILES_PATH:-$ROOT_DIR/profiles.json}" ]]; then
    eval "$(
      node "$ROOT_DIR/scripts/profiles.js" resolve --provider hostinger --format shell
    )"
  fi
fi

if [[ -z "${API_TOKEN:-}" ]]; then
  export API_TOKEN="${HOSTINGER_API_TOKEN:-}"
fi

if [[ -z "${DEBUG:-}" ]]; then
  export DEBUG="${HOSTINGER_MCP_DEBUG:-false}"
fi

if [[ -z "${API_TOKEN:-}" ]]; then
  echo "Missing Hostinger credentials. Set API_TOKEN/HOSTINGER_API_TOKEN in the environment or configure the selected hostinger account in profiles.json." >&2
  exit 1
fi

exec hostinger-api-mcp "$@"
