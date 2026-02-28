param(
  [switch]$NoInit,
  [switch]$Auto,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$CodexArgs
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $PSScriptRoot
Set-Location $RootDir

if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
  throw "codex not found. Run scripts/bootstrap-windows.ps1 first."
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
You are the Hostinger VPS Agent for this repository.

Repository version: $repoVersion

At the start of this session:
1. Briefly explain your purpose.
2. State the repository version above.
3. Ask the user what fleet action they want to do next.
"@

codex @CodexArgs $initPrompt
exit $LASTEXITCODE
