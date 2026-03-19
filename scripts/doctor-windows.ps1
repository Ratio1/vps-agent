$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
Set-Location $RootDir
$ProfilesFile = if ($env:VPS_PROFILES_PATH) { $env:VPS_PROFILES_PATH } else { Join-Path $RootDir "profiles.json" }
$ProfilesLabel = if ($ProfilesFile.StartsWith("$RootDir$([IO.Path]::DirectorySeparatorChar)")) {
  $ProfilesFile.Substring($RootDir.Length + 1)
} else {
  $ProfilesFile
}

function Ok($msg) { Write-Host "[ok] $msg" }
function Warn($msg) { Write-Host "[warn] $msg" }
function Fail($msg) { throw "[fail] $msg" }

if (Get-Command node -ErrorAction SilentlyContinue) { Ok "node: $(node -v)" } else { Fail "node missing" }
if (Get-Command npm -ErrorAction SilentlyContinue) { Ok "npm: $(npm -v)" } else { Fail "npm missing" }
if (Get-Command npx -ErrorAction SilentlyContinue) { Ok "npx available" } else { Fail "npx missing" }
if (Get-Command codex -ErrorAction SilentlyContinue) { Ok "codex installed" } else { Fail "codex missing" }
if (Get-Command hostinger-api-mcp -ErrorAction SilentlyContinue) { Ok "hostinger-api-mcp installed" } else { Fail "hostinger-api-mcp missing" }

if (Test-Path $ProfilesFile) {
  Ok "$ProfilesLabel present"
  try {
    $profilesReport = & node "scripts/profiles.js" validate --file $ProfilesFile --format json
    if ($LASTEXITCODE -ne 0) {
      throw "$ProfilesLabel validation failed"
    }
    $profiles = ($profilesReport -join [Environment]::NewLine) | ConvertFrom-Json
    Ok "$ProfilesLabel parsed successfully"
    Ok "$ProfilesLabel summary: $($profiles.tenants) tenants, $($profiles.accounts.Count) accounts"
    foreach ($validationWarning in $profiles.warnings) {
      Warn $validationWarning
    }

    $hostingerProfiles = (& node "scripts/profiles.js" list --file $ProfilesFile --provider hostinger --format json --optional) -join [Environment]::NewLine | ConvertFrom-Json
    $contaboProfiles = (& node "scripts/profiles.js" list --file $ProfilesFile --provider contabo --format json --optional) -join [Environment]::NewLine | ConvertFrom-Json

    if ($hostingerProfiles.Count -gt 0) {
      Ok "Hostinger account(s) configured in $ProfilesLabel: $($hostingerProfiles.Count)"
    } else {
      Warn "No hostinger accounts configured in $ProfilesLabel"
    }

    if ($contaboProfiles.Count -gt 0) {
      Ok "Contabo account(s) configured in $ProfilesLabel: $($contaboProfiles.Count)"
    } else {
      Warn "No contabo accounts configured in $ProfilesLabel"
    }
  } catch {
    Fail "$ProfilesLabel is invalid"
  }
} else {
  Warn "$ProfilesLabel does not exist"
}

if (Test-Path "scripts/contabo-mcp.ps1") {
  Ok "scripts/contabo-mcp.ps1 present"
} else {
  Warn "scripts/contabo-mcp.ps1 missing"
}

if (Test-Path ".codex/config.toml") {
  Ok ".codex/config.toml present"
  if (Select-String -Path ".codex/config.toml" -Pattern '^\[agents\]\s*$' -SimpleMatch:$false) {
    Ok "[agents] section present in .codex/config.toml"
  } else {
    Warn "[agents] section missing from .codex/config.toml"
  }
  if (Select-String -Path ".codex/config.toml" -Pattern '^\[mcp_servers\.openaiDeveloperDocs\]\s*$' -SimpleMatch:$false) {
    Ok "OpenAI Docs MCP configured in .codex/config.toml"
  } else {
    Warn "OpenAI Docs MCP missing from .codex/config.toml"
  }
} else {
  Warn ".codex/config.toml missing"
}

$requiredCodexAgents = @(
  "ops-explorer.toml",
  "ops-builder.toml",
  "ops-critic.toml",
  "ops-verifier.toml",
  "docs-researcher.toml"
)

if (Test-Path ".codex/agents") {
  Ok ".codex/agents present"
  foreach ($agentFile in $requiredCodexAgents) {
    $agentPath = Join-Path ".codex/agents" $agentFile
    if (Test-Path $agentPath) {
      Ok "$agentPath present"
    } else {
      Warn "$agentPath missing"
    }
  }
} else {
  Warn ".codex/agents missing"
}
