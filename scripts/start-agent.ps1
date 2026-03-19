param(
  [switch]$NoInit,
  [switch]$Auto,
  [switch]$ListProfiles,
  [string]$Tenant,
  [string]$HostingerAccount,
  [string]$ContaboAccount,
  [string]$Profiles,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$CodexArgs
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
Set-Location $RootDir

if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
  throw "codex not found. Run scripts/bootstrap-windows.ps1 first."
}

if (-not [string]::IsNullOrWhiteSpace($Tenant)) { $env:VPS_TENANT = $Tenant }
if (-not [string]::IsNullOrWhiteSpace($HostingerAccount)) { $env:VPS_HOSTINGER_ACCOUNT = $HostingerAccount }
if (-not [string]::IsNullOrWhiteSpace($ContaboAccount)) { $env:VPS_CONTABO_ACCOUNT = $ContaboAccount }
if (-not [string]::IsNullOrWhiteSpace($Profiles)) { $env:VPS_PROFILES_PATH = $Profiles }

if ($ListProfiles) {
  & node "scripts/profiles.js" list --format text --optional
  exit $LASTEXITCODE
}

if ($NoInit) {
  codex @CodexArgs
  exit $LASTEXITCODE
}

$repoVersion = "unknown"
if (Test-Path "ver.yaml") {
  $versionLine = Select-String -Path "ver.yaml" -Pattern '^\s*version\s*:\s*(.+)\s*$' | Select-Object -First 1
  if ($versionLine) {
    $repoVersion = $versionLine.Matches[0].Groups[1].Value.Trim().Trim('"').Trim("'")
  }
}

$initPrompt = @"
You are the VPS Fleet Agent for this repository.

Repository version: $repoVersion
Selected tenant: $(if ($env:VPS_TENANT) { $env:VPS_TENANT } else { "auto" })
Selected Hostinger account: $(if ($env:VPS_HOSTINGER_ACCOUNT) { $env:VPS_HOSTINGER_ACCOUNT } else { "auto" })
Selected Contabo account: $(if ($env:VPS_CONTABO_ACCOUNT) { $env:VPS_CONTABO_ACCOUNT } else { "auto" })

At the start of this session:
1. Briefly explain your purpose.
2. State the repository version above.
3. State the currently selected tenant/account context.
4. Ask the user what fleet action they want to do next.
"@

codex @CodexArgs $initPrompt
exit $LASTEXITCODE
