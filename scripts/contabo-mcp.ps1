param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$RemainingArgs
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot

if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
  throw "npx not found in PATH. Install Node.js/npm first."
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  throw "node not found in PATH. Install Node.js first."
}

if (
  [string]::IsNullOrWhiteSpace($env:CONTABO_MCP_API_KEY)
) {
  $profilesPath = if ([string]::IsNullOrWhiteSpace($env:VPS_PROFILES_PATH)) { (Join-Path $RootDir "profiles.json") } else { $env:VPS_PROFILES_PATH }
  if (Test-Path $profilesPath) {
    $resolved = & node (Join-Path $RootDir "scripts/profiles.js") resolve --provider contabo --format powershell
    if ($LASTEXITCODE -ne 0) {
      throw "Unable to resolve the selected contabo account from profiles.json."
    }
    Invoke-Expression ($resolved -join [Environment]::NewLine)
  }
}

$contaboUrl = if ([string]::IsNullOrWhiteSpace($env:CONTABO_MCP_URL)) { "https://contabo.run.mcp.com.ai/mcp" } else { $env:CONTABO_MCP_URL }
$transport = if ([string]::IsNullOrWhiteSpace($env:CONTABO_MCP_TRANSPORT)) { "http-only" } else { $env:CONTABO_MCP_TRANSPORT }

$apiKey = $env:CONTABO_MCP_API_KEY

if ([string]::IsNullOrWhiteSpace($apiKey)) {
  throw "Missing Contabo MCP connector key. Configure CONTABO_MCP_API_KEY in the environment or selected contabo profile. For the official Contabo REST API path, use scripts/contabo-api.js with CLIENT_ID/CLIENT_SECRET/API_USER/API_PASSWORD or CONTABO_ACCESS_TOKEN."
}

# Keep credential out of process args and suppress mcp-remote stderr logs by default.
$env:CONTABO_RUNTIME_API_KEY = $apiKey

& npx -y mcp-remote@latest `
  $contaboUrl `
  --transport $transport `
  --silent `
  --header 'X-API-Key: ${CONTABO_RUNTIME_API_KEY}' `
  @RemainingArgs

exit $LASTEXITCODE
