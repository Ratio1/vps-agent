#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

AUTO=0
NO_INIT=0
codex_args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto)
      AUTO=1
      shift
      ;;
    --no-init)
      NO_INIT=1
      shift
      ;;
    *)
      codex_args+=("$1")
      shift
      ;;
  esac
done

if ! command -v codex >/dev/null 2>&1; then
  echo "codex not found. Run ./scripts/bootstrap-unix.sh first." >&2
  exit 1
fi

if (( AUTO == 1 )) && [[ ! -t 0 || ! -t 1 ]]; then
  echo "Skipping Codex auto-start: non-interactive terminal."
  exit 0
fi

if (( NO_INIT == 1 )); then
  exec codex "${codex_args[@]}"
fi

REPO_VERSION="unknown"
if [[ -f "ver.yaml" ]]; then
  parsed_version="$(awk -F': *' '/^[[:space:]]*version[[:space:]]*:/ {print $2; exit}' ver.yaml | tr -d "\"'[:space:]")"
  if [[ -n "$parsed_version" ]]; then
    REPO_VERSION="$parsed_version"
  fi
fi

INIT_PROMPT=$(cat <<EOF
You are the Hostinger VPS Agent for this repository.

Repository version: ${REPO_VERSION}

At the start of this session:
1. Briefly explain your purpose.
2. State the repository version above.
3. Ask the user what fleet action they want to do next.
EOF
)

exec codex "${codex_args[@]}" "$INIT_PROMPT"
