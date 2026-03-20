#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

AUTO=0
NO_INIT=0
LIST_PROFILES=0
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
    --list-profiles)
      LIST_PROFILES=1
      shift
      ;;
    --tenant)
      export VPS_TENANT="${2:-}"
      shift 2
      ;;
    --hostinger-account)
      export VPS_HOSTINGER_ACCOUNT="${2:-}"
      shift 2
      ;;
    --contabo-account)
      export VPS_CONTABO_ACCOUNT="${2:-}"
      shift 2
      ;;
    --profiles)
      export VPS_PROFILES_PATH="${2:-}"
      shift 2
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

if (( LIST_PROFILES == 1 )); then
  exec node "$ROOT_DIR/scripts/profiles.js" list --format text --optional
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
You are the VPS Fleet Agent for this repository.

Repository version: ${REPO_VERSION}
Selected tenant: ${VPS_TENANT:-none}
Initial provider context: none unless explicit selectors were passed for this session.

At the start of this session:
1. Briefly explain your purpose.
2. State the repository version above.
3. State the currently selected tenant context, which may be none.
4. If no tenant/provider context is selected, ask the user which tenant and provider to use for the next fleet action.
EOF
)

exec codex "${codex_args[@]}" "$INIT_PROMPT"
