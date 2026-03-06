$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
Set-Location $RootDir

function Ok($msg) { Write-Host "[ok] $msg" }
function Warn($msg) { Write-Host "[warn] $msg" }
function Fail($msg) { throw "[fail] $msg" }

if (Get-Command node -ErrorAction SilentlyContinue) { Ok "node: $(node -v)" } else { Fail "node missing" }
if (Get-Command npm -ErrorAction SilentlyContinue) { Ok "npm: $(npm -v)" } else { Fail "npm missing" }
if (Get-Command npx -ErrorAction SilentlyContinue) { Ok "npx available" } else { Fail "npx missing" }
if (Get-Command codex -ErrorAction SilentlyContinue) { Ok "codex installed" } else { Fail "codex missing" }
if (Get-Command hostinger-api-mcp -ErrorAction SilentlyContinue) { Ok "hostinger-api-mcp installed" } else { Fail "hostinger-api-mcp missing" }

$envFile = Join-Path $RootDir ".env"
$hasContaboMcpHint = $false
$hasContaboClientSecret = $false
$hasContaboClientId = $false

if (Test-Path $envFile) {
  $hasToken = (Select-String -Path $envFile -Pattern '^\s*HOSTINGER_API_TOKEN\s*=\s*.+$' -SimpleMatch:$false)
  if ($hasToken) { Ok "HOSTINGER_API_TOKEN appears set in .env" } else { Warn "HOSTINGER_API_TOKEN appears empty in .env" }

  $hasContaboMcpHint = [bool](Select-String -Path $envFile -Pattern '^\s*(CONTABO_MCP_API_KEY|CONTABO_ACCESS_TOKEN)\s*=\s*.+$' -SimpleMatch:$false)
  $hasContaboClientSecret = [bool](Select-String -Path $envFile -Pattern '^\s*CONTABO_CLIENT_SECRET\s*=\s*.+$' -SimpleMatch:$false)
  $hasContaboClientId = [bool](Select-String -Path $envFile -Pattern '^\s*CONTABO_CLIENT_ID\s*=\s*.+$' -SimpleMatch:$false)
} else {
  Warn ".env does not exist"
}

if (Test-Path "scripts/contabo-mcp.ps1") {
  Ok "scripts/contabo-mcp.ps1 present"
} else {
  Warn "scripts/contabo-mcp.ps1 missing"
}

if ($hasContaboMcpHint) {
  Ok "Contabo MCP auth hint appears set"
} elseif ($hasContaboClientSecret) {
  Ok "Contabo client secret appears set (used as Contabo MCP API key)"
} elseif ($hasContaboClientId) {
  Warn "CONTABO_CLIENT_ID is set but no Contabo MCP auth hint found"
}

if (Test-Path ".codex/config.toml") {
  Ok ".codex/config.toml present"
} else {
  Warn ".codex/config.toml missing"
}
