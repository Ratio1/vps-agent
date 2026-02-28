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

if (-not (Get-Command hostinger-api-mcp -ErrorAction SilentlyContinue)) {
  throw "hostinger-api-mcp not found in PATH. Install with: npm install -g hostinger-api-mcp"
}

if ([string]::IsNullOrWhiteSpace($env:HOSTINGER_API_TOKEN) -and [string]::IsNullOrWhiteSpace($env:API_TOKEN)) {
  throw "Missing HOSTINGER_API_TOKEN in .env (or API_TOKEN in environment)."
}

if ([string]::IsNullOrWhiteSpace($env:API_TOKEN)) {
  $env:API_TOKEN = $env:HOSTINGER_API_TOKEN
}

if ([string]::IsNullOrWhiteSpace($env:DEBUG)) {
  if ([string]::IsNullOrWhiteSpace($env:HOSTINGER_MCP_DEBUG)) {
    $env:DEBUG = "false"
  } else {
    $env:DEBUG = $env:HOSTINGER_MCP_DEBUG
  }
}

& hostinger-api-mcp @RemainingArgs
exit $LASTEXITCODE
