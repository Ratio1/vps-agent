#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f ".env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source ".env"
  set +a
fi

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
declare -a FAILURE_PROVIDERS=()
USE_LOCAL_SESSIONS="$(echo "${REGRESSION_USE_LOCAL_SESSIONS:-false}" | tr '[:upper:]' '[:lower:]')"

ok() { echo "[pass] $1"; }
warn() { echo "[skip] $1"; }
err() { echo "[fail] $1"; }

sha1_hex() {
  if command -v sha1sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha1sum | awk '{print $1}'
    return 0
  fi

  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 1 | awk '{print $1}'
    return 0
  fi

  return 1
}

run_provider() {
  local provider="$1"
  shift

  local rc
  if "$@"; then
    rc=0
  else
    rc=$?
  fi

  if [[ "$rc" -eq 0 ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
    return 0
  fi

  if [[ "$rc" -eq 10 ]]; then
    SKIP_COUNT=$((SKIP_COUNT + 1))
    return 0
  fi

  FAIL_COUNT=$((FAIL_COUNT + 1))
  FAILURE_PROVIDERS+=("$provider")
  return 0
}

test_hostinger() {
  local token="${HOSTINGER_API_TOKEN:-${API_TOKEN:-}}"
  if [[ -z "$token" ]]; then
    warn "hostinger: token not configured (HOSTINGER_API_TOKEN/API_TOKEN)"
    return 10
  fi

  local response
  if ! response="$(
    curl -fsS \
      -H "Authorization: Bearer $token" \
      -H "Accept: application/json" \
      "https://developers.hostinger.com/api/vps/v1/virtual-machines"
  )"; then
    err "hostinger: unable to list VPS instances"
    return 1
  fi

  local count
  count="$(jq -r '
    if type == "array" then length
    elif (.data | type == "array") then (.data | length)
    else -1
    end
  ' <<<"$response")"

  if ! [[ "$count" =~ ^[0-9]+$ ]]; then
    err "hostinger: unexpected API payload shape"
    return 1
  fi

  local missing_state_count
  missing_state_count="$(jq -r '
    (if type == "array" then . elif (.data | type == "array") then .data else [] end)
    | map(select((.state // .status // "") == ""))
    | length
  ' <<<"$response")"

  if [[ "$missing_state_count" != "0" ]]; then
    err "hostinger: $missing_state_count VPS entries missing state/status"
    return 1
  fi

  local states
  states="$(jq -c '
    (if type == "array" then . elif (.data | type == "array") then .data else [] end)
    | map(.state // .status // "unknown")
    | group_by(.)
    | map({state: .[0], count: length})
  ' <<<"$response")"

  ok "hostinger: listed $count VPS; state distribution: $states"
  return 0
}

test_aws() {
  local has_auth_hint=0
  if [[ -n "${AWS_PROFILE:-}" ]] || { [[ -n "${AWS_ACCESS_KEY_ID:-}" ]] && [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; }; then
    has_auth_hint=1
  fi

  if [[ "$has_auth_hint" -eq 0 ]] && [[ ! "$USE_LOCAL_SESSIONS" =~ ^(1|true|yes|y)$ ]]; then
    warn "aws: skipped (no .env auth hints; set REGRESSION_USE_LOCAL_SESSIONS=true to use local CLI sessions)"
    return 10
  fi

  if ! command -v aws >/dev/null 2>&1; then
    if [[ "$has_auth_hint" -eq 1 ]]; then
      err "aws: credentials are present but aws CLI is missing"
      return 1
    fi
    warn "aws: CLI not installed and no AWS credentials configured"
    return 10
  fi

  if ! aws sts get-caller-identity --output json >/dev/null 2>&1; then
    if [[ "$has_auth_hint" -eq 1 ]]; then
      err "aws: credentials configured but authentication failed"
      return 1
    fi
    warn "aws: no active credentials/auth session"
    return 10
  fi

  local region="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
  if [[ -z "$region" ]]; then
    region="$(aws configure get region 2>/dev/null || true)"
  fi
  if [[ -z "$region" ]]; then
    region="us-east-1"
  fi

  local response
  if ! response="$(aws ec2 describe-instances --region "$region" --output json 2>/dev/null)"; then
    err "aws: failed to describe instances in region $region"
    return 1
  fi

  local count
  count="$(jq -r '[.Reservations[]?.Instances[]?] | length' <<<"$response")"
  local states
  states="$(jq -c '
    [.Reservations[]?.Instances[]?.State?.Name // "unknown"]
    | group_by(.)
    | map({state: .[0], count: length})
  ' <<<"$response")"

  ok "aws: listed $count instances in region $region; state distribution: $states"
  return 0
}

test_gcp() {
  local has_auth_hint=0
  if [[ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]] || [[ -n "${CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE:-}" ]]; then
    has_auth_hint=1
  fi

  if [[ "$has_auth_hint" -eq 0 ]] && [[ ! "$USE_LOCAL_SESSIONS" =~ ^(1|true|yes|y)$ ]]; then
    warn "gcp: skipped (no .env auth hints; set REGRESSION_USE_LOCAL_SESSIONS=true to use local CLI sessions)"
    return 10
  fi

  if ! command -v gcloud >/dev/null 2>&1; then
    if [[ "$has_auth_hint" -eq 1 ]]; then
      err "gcp: credentials hint present but gcloud CLI is missing"
      return 1
    fi
    warn "gcp: gcloud CLI not installed and no GCP credentials configured"
    return 10
  fi

  local active_account
  active_account="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null | head -n 1 || true)"

  if [[ -z "$active_account" ]] && [[ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ]] && [[ -f "${GOOGLE_APPLICATION_CREDENTIALS}" ]]; then
    gcloud auth activate-service-account --key-file="${GOOGLE_APPLICATION_CREDENTIALS}" --quiet >/dev/null 2>&1 || true
    active_account="$(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null | head -n 1 || true)"
  fi

  if [[ -z "$active_account" ]]; then
    if [[ "$has_auth_hint" -eq 1 ]]; then
      err "gcp: credentials configured but no active gcloud auth session"
      return 1
    fi
    warn "gcp: no active gcloud auth session"
    return 10
  fi

  local project="${GOOGLE_CLOUD_PROJECT:-}"
  if [[ -z "$project" ]]; then
    project="$(gcloud config get-value project 2>/dev/null | tr -d '[:space:]' || true)"
  fi
  if [[ -z "$project" ]] || [[ "$project" == "(unset)" ]]; then
    err "gcp: authenticated but no project configured (set GOOGLE_CLOUD_PROJECT or gcloud config project)"
    return 1
  fi

  local response
  if ! response="$(gcloud compute instances list --project "$project" --format=json 2>/dev/null)"; then
    err "gcp: failed to list compute instances for project $project"
    return 1
  fi

  local count
  count="$(jq -r 'length' <<<"$response")"
  local states
  states="$(jq -c '
    map(.status // "unknown")
    | group_by(.)
    | map({state: .[0], count: length})
  ' <<<"$response")"

  ok "gcp: listed $count instances in project $project; state distribution: $states"
  return 0
}

test_azure() {
  local client_id="${AZURE_CLIENT_ID:-${ARM_CLIENT_ID:-}}"
  local tenant_id="${AZURE_TENANT_ID:-${ARM_TENANT_ID:-}}"
  local client_secret="${AZURE_CLIENT_SECRET:-${ARM_CLIENT_SECRET:-}}"
  local subscription_id="${AZURE_SUBSCRIPTION_ID:-${ARM_SUBSCRIPTION_ID:-}}"
  local has_sp_hint=0

  if [[ -n "$client_id" ]] && [[ -n "$tenant_id" ]] && [[ -n "$client_secret" ]]; then
    has_sp_hint=1
  fi

  if [[ "$has_sp_hint" -eq 0 ]] && [[ -z "$subscription_id" ]] && [[ ! "$USE_LOCAL_SESSIONS" =~ ^(1|true|yes|y)$ ]]; then
    warn "azure: skipped (no .env auth hints; set REGRESSION_USE_LOCAL_SESSIONS=true to use local CLI sessions)"
    return 10
  fi

  if ! command -v az >/dev/null 2>&1; then
    if [[ "$has_sp_hint" -eq 1 ]]; then
      err "azure: service principal credentials are present but az CLI is missing"
      return 1
    fi
    warn "azure: az CLI not installed and no Azure credentials configured"
    return 10
  fi

  if ! az account show >/dev/null 2>&1; then
    if [[ "$has_sp_hint" -eq 1 ]]; then
      if ! az login --service-principal \
        --username "$client_id" \
        --password "$client_secret" \
        --tenant "$tenant_id" \
        --output none >/dev/null 2>&1; then
        err "azure: service principal login failed"
        return 1
      fi
    else
      warn "azure: no active az login session"
      return 10
    fi
  fi

  if [[ -n "$subscription_id" ]]; then
    if ! az account set --subscription "$subscription_id" >/dev/null 2>&1; then
      err "azure: failed to select subscription $subscription_id"
      return 1
    fi
  fi

  local response
  if ! response="$(az vm list -d --output json 2>/dev/null)"; then
    err "azure: failed to list virtual machines"
    return 1
  fi

  local count
  count="$(jq -r 'length' <<<"$response")"
  local states
  states="$(jq -c '
    map(.powerState // "unknown")
    | group_by(.)
    | map({state: .[0], count: length})
  ' <<<"$response")"

  ok "azure: listed $count VMs; power-state distribution: $states"
  return 0
}

resolve_ovh_base_url() {
  local endpoint="${OVH_ENDPOINT:-ovh-eu}"
  case "$endpoint" in
    http://*|https://*)
      printf '%s' "${endpoint%/}"
      ;;
    ovh-eu)
      printf '%s' "https://eu.api.ovh.com/1.0"
      ;;
    ovh-us)
      printf '%s' "https://api.us.ovhcloud.com/1.0"
      ;;
    ovh-ca)
      printf '%s' "https://ca.api.ovh.com/1.0"
      ;;
    *)
      printf '%s' "https://eu.api.ovh.com/1.0"
      ;;
  esac
}

ovh_signed_request() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local base_url="$4"
  local full_url="${base_url}${path}"

  local timestamp
  timestamp="$(curl -fsS "${base_url}/auth/time")"

  local sign_payload="${OVH_APPLICATION_SECRET}+${OVH_CONSUMER_KEY}+${method}+${full_url}+${body}+${timestamp}"
  local digest
  digest="$(sha1_hex "$sign_payload")" || return 1
  local signature="\$1\$$digest"

  if [[ -n "$body" ]]; then
    curl -fsS \
      -X "$method" \
      -H "Content-Type: application/json" \
      -H "X-Ovh-Application: ${OVH_APPLICATION_KEY}" \
      -H "X-Ovh-Consumer: ${OVH_CONSUMER_KEY}" \
      -H "X-Ovh-Timestamp: ${timestamp}" \
      -H "X-Ovh-Signature: ${signature}" \
      --data "$body" \
      "$full_url"
    return
  fi

  curl -fsS \
    -X "$method" \
    -H "Content-Type: application/json" \
    -H "X-Ovh-Application: ${OVH_APPLICATION_KEY}" \
    -H "X-Ovh-Consumer: ${OVH_CONSUMER_KEY}" \
    -H "X-Ovh-Timestamp: ${timestamp}" \
    -H "X-Ovh-Signature: ${signature}" \
    "$full_url"
}

test_ovh() {
  if [[ -z "${OVH_APPLICATION_KEY:-}" ]] || [[ -z "${OVH_APPLICATION_SECRET:-}" ]] || [[ -z "${OVH_CONSUMER_KEY:-}" ]]; then
    warn "ovh: credentials not configured (OVH_APPLICATION_KEY/OVH_APPLICATION_SECRET/OVH_CONSUMER_KEY)"
    return 10
  fi

  if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    err "ovh: requires curl and jq"
    return 1
  fi

  local base_url
  base_url="$(resolve_ovh_base_url)"

  local services
  if ! services="$(ovh_signed_request "GET" "/vps" "" "$base_url" 2>/dev/null)"; then
    err "ovh: failed to list VPS services from $base_url"
    return 1
  fi

  local service_count
  service_count="$(jq -r 'length' <<<"$services")"

  if [[ "$service_count" == "0" ]]; then
    ok "ovh: listed 0 VPS services"
    return 0
  fi

  local details='[]'
  local service
  while IFS= read -r service; do
    local encoded
    encoded="$(jq -rn --arg s "$service" '$s|@uri')"

    local detail
    if ! detail="$(ovh_signed_request "GET" "/vps/${encoded}" "" "$base_url" 2>/dev/null)"; then
      err "ovh: failed to fetch details for VPS service $service"
      return 1
    fi

    local state
    state="$(jq -r '.state // .status // "unknown"' <<<"$detail")"
    details="$(jq -c --arg svc "$service" --arg state "$state" '. + [{service: $svc, state: $state}]' <<<"$details")"
  done < <(jq -r '.[]' <<<"$services")

  local states
  states="$(jq -c 'group_by(.state) | map({state: .[0].state, count: length})' <<<"$details")"

  ok "ovh: listed $service_count VPS services; state distribution: $states"
  return 0
}

echo "Running provider regression checks (read/list only)..."
run_provider "hostinger" test_hostinger
run_provider "aws" test_aws
run_provider "gcp" test_gcp
run_provider "azure" test_azure
run_provider "ovh" test_ovh

echo
echo "Summary: pass=$PASS_COUNT skip=$SKIP_COUNT fail=$FAIL_COUNT"
if (( FAIL_COUNT > 0 )); then
  echo "Failed providers: ${FAILURE_PROVIDERS[*]}"
  exit 1
fi
