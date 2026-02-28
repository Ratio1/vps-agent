$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
Set-Location $RootDir

function Ok($msg) { Write-Host "[ok] $msg" }
function Warn($msg) { Write-Host "[warn] $msg" }
function Fail($msg) { throw "[fail] $msg" }

if (Get-Command node -ErrorAction SilentlyContinue) { Ok "node: $(node -v)" } else { Fail "node missing" }
if (Get-Command npm -ErrorAction SilentlyContinue) { Ok "npm: $(npm -v)" } else { Fail "npm missing" }
if (Get-Command codex -ErrorAction SilentlyContinue) { Ok "codex installed" } else { Fail "codex missing" }
if (Get-Command hostinger-api-mcp -ErrorAction SilentlyContinue) { Ok "hostinger-api-mcp installed" } else { Fail "hostinger-api-mcp missing" }

$envFile = Join-Path $RootDir ".env"
if (Test-Path $envFile) {
  $hasToken = (Select-String -Path $envFile -Pattern '^\s*HOSTINGER_API_TOKEN\s*=\s*.+$' -SimpleMatch:$false)
  if ($hasToken) { Ok "HOSTINGER_API_TOKEN appears set in .env" } else { Warn "HOSTINGER_API_TOKEN appears empty in .env" }
} else {
  Warn ".env does not exist"
}

if (Test-Path ".codex/config.toml") {
  Ok ".codex/config.toml present"
} else {
  Warn ".codex/config.toml missing"
}
