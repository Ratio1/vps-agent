param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$RemainingArgs
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
$EnvFile = Join-Path $RootDir ".env"

if (Test-Path $EnvFile) {
  Get-Content $EnvFile | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -match '^\s*$') {
      return
    }

    $parts = $_ -split '=', 2
    if ($parts.Count -eq 2) {
      $name = $parts[0].Trim()
      $value = $parts[1].Trim().Trim('"').Trim("'")
      [Environment]::SetEnvironmentVariable($name, $value, "Process")
    }
  }
}

if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
  throw "npx not found in PATH. Install Node.js/npm first."
}

$contaboUrl = if ([string]::IsNullOrWhiteSpace($env:CONTABO_MCP_URL)) { "https://contabo.run.mcp.com.ai/mcp" } else { $env:CONTABO_MCP_URL }
$transport = if ([string]::IsNullOrWhiteSpace($env:CONTABO_MCP_TRANSPORT)) { "http-only" } else { $env:CONTABO_MCP_TRANSPORT }

$apiKey = $null
if (-not [string]::IsNullOrWhiteSpace($env:CONTABO_MCP_API_KEY)) {
  $apiKey = $env:CONTABO_MCP_API_KEY
} elseif (-not [string]::IsNullOrWhiteSpace($env:CONTABO_ACCESS_TOKEN)) {
  $apiKey = $env:CONTABO_ACCESS_TOKEN
} elseif (-not [string]::IsNullOrWhiteSpace($env:CONTABO_CLIENT_SECRET)) {
  $apiKey = $env:CONTABO_CLIENT_SECRET
}

if ([string]::IsNullOrWhiteSpace($apiKey)) {
  throw "Missing Contabo MCP credentials. Set one of CONTABO_MCP_API_KEY, CONTABO_ACCESS_TOKEN, or CONTABO_CLIENT_SECRET in .env."
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
