param(
  [switch]$SkipInstall
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
Set-Location $RootDir

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  throw "Node.js is required (>=20)."
}

$nodeVersion = node -p "process.versions.node"
$major = [int](node -p "process.versions.node.split('.')[0]")
if ($major -lt 20) {
  throw "Node.js >=20 is required. Current: $nodeVersion"
}

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
  throw "npm is required."
}

if (-not $SkipInstall) {
  Write-Host "Installing global tools: @openai/codex, hostinger-api-mcp"
  npm install -g @openai/codex hostinger-api-mcp
}

if (-not (Test-Path "profiles.json")) {
  Copy-Item "profiles.json.template" "profiles.json"
  Write-Host "Created profiles.json from profiles.json.template."
}

if (-not (Test-Path ".codex")) {
  New-Item -ItemType Directory -Path ".codex" | Out-Null
}

if (-not (Test-Path ".codex/config.toml")) {
  Copy-Item ".codex/config.windows.toml.example" ".codex/config.toml"
  Write-Host "Created .codex/config.toml from Windows template."
}

if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
  throw "codex command not found after installation."
}

if (-not (Get-Command hostinger-api-mcp -ErrorAction SilentlyContinue)) {
  throw "hostinger-api-mcp command not found after installation."
}

Write-Host "Bootstrap complete. Next steps:"
Write-Host "1) Update profiles.json with your tenant/provider credentials"
Write-Host "2) Review configured provider entries: node scripts/profiles.js list --format text"
Write-Host "3) Run: powershell -ExecutionPolicy Bypass -File scripts/doctor-windows.ps1"
Write-Host "4) Start Codex in this repo: powershell -ExecutionPolicy Bypass -File scripts/start-agent.ps1"
