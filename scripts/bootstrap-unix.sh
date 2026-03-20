#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SKIP_INSTALL=0
for arg in "$@"; do
  case "$arg" in
    --skip-install)
      SKIP_INSTALL=1
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Usage: ./scripts/bootstrap-unix.sh [--skip-install]" >&2
      exit 1
      ;;
  esac
done

if ! command -v node >/dev/null 2>&1; then
  echo "Node.js is required (>=20)." >&2
  exit 1
fi

NODE_MAJOR="$(node -p "process.versions.node.split('.')[0]")"
if (( NODE_MAJOR < 20 )); then
  echo "Node.js >=20 is required. Current: $(node -v)" >&2
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "npm is required." >&2
  exit 1
fi

if (( SKIP_INSTALL == 0 )); then
  echo "Installing global tools: @openai/codex, hostinger-api-mcp"
  npm install -g @openai/codex hostinger-api-mcp
fi

if [[ ! -f "profiles.json" ]]; then
  cp profiles.json.template profiles.json
  echo "Created profiles.json from profiles.json.template."
fi

mkdir -p .codex
if [[ ! -f ".codex/config.toml" ]]; then
  cp .codex/config.toml.example .codex/config.toml
  echo "Created .codex/config.toml from Linux/macOS template."
fi

if ! command -v codex >/dev/null 2>&1; then
  echo "codex command not found after installation." >&2
  exit 1
fi

if ! command -v hostinger-api-mcp >/dev/null 2>&1; then
  echo "hostinger-api-mcp command not found after installation." >&2
  exit 1
fi

echo "Bootstrap complete. Next steps:"
echo "1) Update profiles.json with your tenant/provider credentials"
echo "2) Review configured provider entries: node scripts/profiles.js list --format text"
echo "3) Run: ./scripts/doctor-unix.sh"
echo "4) Start Codex in this repo: bash scripts/start-agent.sh"
