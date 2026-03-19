$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $PSScriptRoot
Set-Location $RootDir

$PassCount = 0
$FailCount = 0
$SkipCount = 0
$FailedProviders = New-Object System.Collections.Generic.List[string]
$ProfilesFile = if ($env:VPS_PROFILES_PATH) { $env:VPS_PROFILES_PATH } else { Join-Path $RootDir "profiles.json" }
$UseLocalSessions = if ($env:REGRESSION_USE_LOCAL_SESSIONS) {
  @("1", "true", "yes", "y") -contains $env:REGRESSION_USE_LOCAL_SESSIONS.ToLowerInvariant()
} else {
  $false
}

function Pass([string]$message) { Write-Host "[pass] $message" }
function Skip([string]$message) { Write-Host "[skip] $message" }
function Fail([string]$message) { Write-Host "[fail] $message" }

function Load-ProviderProfile {
  param(
    [Parameter(Mandatory = $true)][string]$Provider
  )

  if (-not (Test-Path $script:ProfilesFile)) {
    return $true
  }

  $accountsRaw = & node "scripts/profiles.js" list --provider $Provider --format json --optional
  if ($LASTEXITCODE -ne 0) {
    return $false
  }

  $accountsJson = $accountsRaw -join [Environment]::NewLine
  if ([string]::IsNullOrWhiteSpace($accountsJson)) {
    return $true
  }

  $accounts = @($accountsJson | ConvertFrom-Json)
  if ($accounts.Count -eq 0) {
    return $true
  }

  $resolved = & node "scripts/profiles.js" resolve --provider $Provider --format powershell
  if ($LASTEXITCODE -ne 0) {
    return $false
  }

  if ($resolved) {
    Invoke-Expression (($resolved -join [Environment]::NewLine))
  }

  return $true
}

function Invoke-ProviderTest {
  param(
    [Parameter(Mandatory = $true)][string]$Provider,
    [Parameter(Mandatory = $true)][scriptblock]$Test
  )

  $result = & $Test
  switch ($result.status) {
    "pass" {
      $script:PassCount++
      return
    }
    "skip" {
      $script:SkipCount++
      return
    }
    default {
      $script:FailCount++
      $script:FailedProviders.Add($Provider)
      return
    }
  }
}

function Test-Hostinger {
  if (-not (Load-ProviderProfile -Provider "hostinger")) {
    Fail "hostinger: unable to resolve the selected profile"
    return @{ status = "fail" }
  }

  $token = if ($env:HOSTINGER_API_TOKEN) { $env:HOSTINGER_API_TOKEN } else { $env:API_TOKEN }
  if ([string]::IsNullOrWhiteSpace($token)) {
    Skip "hostinger: token not configured (selected profile or API_TOKEN/HOSTINGER_API_TOKEN)"
    return @{ status = "skip" }
  }

  try {
    $response = Invoke-RestMethod -Method Get -Uri "https://developers.hostinger.com/api/vps/v1/virtual-machines" -Headers @{
      Authorization = "Bearer $token"
      Accept        = "application/json"
    }
  } catch {
    Fail "hostinger: unable to list VPS instances"
    return @{ status = "fail" }
  }

  $items = @()
  if ($response -is [System.Array]) {
    $items = $response
  } elseif ($null -ne $response.data -and $response.data -is [System.Array]) {
    $items = $response.data
  } else {
    Fail "hostinger: unexpected API payload shape"
    return @{ status = "fail" }
  }

  $missingState = ($items | Where-Object { [string]::IsNullOrWhiteSpace($_.state) -and [string]::IsNullOrWhiteSpace($_.status) }).Count
  if ($missingState -gt 0) {
    Fail "hostinger: $missingState VPS entries missing state/status"
    return @{ status = "fail" }
  }

  $stateCounts = @{}
  foreach ($item in $items) {
    $state = if ([string]::IsNullOrWhiteSpace($item.state)) { if ([string]::IsNullOrWhiteSpace($item.status)) { "unknown" } else { $item.status } } else { $item.state }
    if (-not $stateCounts.ContainsKey($state)) {
      $stateCounts[$state] = 0
    }
    $stateCounts[$state]++
  }

  Pass "hostinger: listed $($items.Count) VPS; state distribution: $($stateCounts | ConvertTo-Json -Compress)"
  return @{ status = "pass" }
}

function Test-Contabo {
  if (-not (Load-ProviderProfile -Provider "contabo")) {
    Fail "contabo: unable to resolve the selected profile"
    return @{ status = "fail" }
  }

  $accessToken = if ($env:CONTABO_ACCESS_TOKEN) { $env:CONTABO_ACCESS_TOKEN } else { $env:ACCESS_TOKEN }
  $clientId = if ($env:CONTABO_CLIENT_ID) { $env:CONTABO_CLIENT_ID } else { $env:CLIENT_ID }
  $clientSecret = if ($env:CONTABO_CLIENT_SECRET) { $env:CONTABO_CLIENT_SECRET } else { $env:CLIENT_SECRET }
  $apiUser = if ($env:CONTABO_API_USER) { $env:CONTABO_API_USER } else { $env:API_USER }
  $apiPassword = if ($env:CONTABO_API_PASSWORD) { $env:CONTABO_API_PASSWORD } else { $env:API_PASSWORD }

  if (
    [string]::IsNullOrWhiteSpace($accessToken) -and (
      [string]::IsNullOrWhiteSpace($clientId) -or
      [string]::IsNullOrWhiteSpace($clientSecret) -or
      [string]::IsNullOrWhiteSpace($apiUser) -or
      [string]::IsNullOrWhiteSpace($apiPassword)
    )
  ) {
    Skip "contabo: credentials not configured (CONTABO_ACCESS_TOKEN or CLIENT_ID/CLIENT_SECRET/API_USER/API_PASSWORD)"
    return @{ status = "skip" }
  }

  $responseJson = $null
  try {
    $responseJson = & node "scripts/contabo-api.js" list-instances --format json 2>$null
    if ($LASTEXITCODE -ne 0) {
      throw "contabo-api.js failed"
    }
  } catch {
    Fail "contabo: unable to list compute instances"
    return @{ status = "fail" }
  }

  $payload = ($responseJson -join [Environment]::NewLine) | ConvertFrom-Json
  $items = @()
  if ($payload -is [System.Array]) {
    $items = $payload
  } elseif ($null -ne $payload.data -and $payload.data -is [System.Array]) {
    $items = $payload.data
  } elseif ($null -ne $payload.instances -and $payload.instances -is [System.Array]) {
    $items = $payload.instances
  } else {
    Fail "contabo: unexpected API payload shape"
    return @{ status = "fail" }
  }

  $stateCounts = @{}
  foreach ($item in $items) {
    $state = if ([string]::IsNullOrWhiteSpace($item.status)) { if ([string]::IsNullOrWhiteSpace($item.state)) { "unknown" } else { $item.state } } else { $item.status }
    if (-not $stateCounts.ContainsKey($state)) {
      $stateCounts[$state] = 0
    }
    $stateCounts[$state]++
  }

  Pass "contabo: listed $($items.Count) instances; state distribution: $($stateCounts | ConvertTo-Json -Compress)"
  return @{ status = "pass" }
}

function Test-Aws {
  if (-not (Load-ProviderProfile -Provider "aws")) {
    Fail "aws: unable to resolve the selected profile"
    return @{ status = "fail" }
  }

  $hasAuthHint = -not [string]::IsNullOrWhiteSpace($env:AWS_PROFILE) -or (
    -not [string]::IsNullOrWhiteSpace($env:AWS_ACCESS_KEY_ID) -and
    -not [string]::IsNullOrWhiteSpace($env:AWS_SECRET_ACCESS_KEY)
  )

  if (-not $hasAuthHint -and -not $script:UseLocalSessions) {
    Skip "aws: skipped (no selected profile credentials; set REGRESSION_USE_LOCAL_SESSIONS=true to use local CLI sessions)"
    return @{ status = "skip" }
  }

  if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    if ($hasAuthHint) {
      Fail "aws: credentials are present but aws CLI is missing"
      return @{ status = "fail" }
    }
    Skip "aws: CLI not installed and no AWS credentials configured"
    return @{ status = "skip" }
  }

  try {
    aws sts get-caller-identity --output json 1>$null 2>$null
  } catch {
    if ($hasAuthHint) {
      Fail "aws: credentials configured but authentication failed"
      return @{ status = "fail" }
    }
    Skip "aws: no active credentials/auth session"
    return @{ status = "skip" }
  }

  $region = $env:AWS_REGION
  if ([string]::IsNullOrWhiteSpace($region)) { $region = $env:AWS_DEFAULT_REGION }
  if ([string]::IsNullOrWhiteSpace($region)) {
    try {
      $region = (aws configure get region 2>$null).Trim()
    } catch {
      $region = ""
    }
  }
  if ([string]::IsNullOrWhiteSpace($region)) { $region = "us-east-1" }

  $raw = $null
  try {
    $raw = aws ec2 describe-instances --region $region --output json 2>$null
  } catch {
    Fail "aws: failed to describe instances in region $region"
    return @{ status = "fail" }
  }

  $parsed = $raw | ConvertFrom-Json
  $instances = @()
  foreach ($reservation in $parsed.Reservations) {
    foreach ($instance in $reservation.Instances) {
      $instances += $instance
    }
  }

  $stateCounts = @{}
  foreach ($instance in $instances) {
    $state = if ($instance.State.Name) { $instance.State.Name } else { "unknown" }
    if (-not $stateCounts.ContainsKey($state)) { $stateCounts[$state] = 0 }
    $stateCounts[$state]++
  }

  Pass "aws: listed $($instances.Count) instances in region $region; state distribution: $($stateCounts | ConvertTo-Json -Compress)"
  return @{ status = "pass" }
}

function Test-Gcp {
  if (-not (Load-ProviderProfile -Provider "gcp")) {
    Fail "gcp: unable to resolve the selected profile"
    return @{ status = "fail" }
  }

  $hasAuthHint = -not [string]::IsNullOrWhiteSpace($env:GOOGLE_APPLICATION_CREDENTIALS) -or -not [string]::IsNullOrWhiteSpace($env:CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE)

  if (-not $hasAuthHint -and -not $script:UseLocalSessions) {
    Skip "gcp: skipped (no selected profile credentials; set REGRESSION_USE_LOCAL_SESSIONS=true to use local CLI sessions)"
    return @{ status = "skip" }
  }

  if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
    if ($hasAuthHint) {
      Fail "gcp: credentials hint present but gcloud CLI is missing"
      return @{ status = "fail" }
    }
    Skip "gcp: gcloud CLI not installed and no GCP credentials configured"
    return @{ status = "skip" }
  }

  $activeAccount = ""
  try {
    $activeAccount = (gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>$null | Select-Object -First 1).Trim()
  } catch {
    $activeAccount = ""
  }

  if ([string]::IsNullOrWhiteSpace($activeAccount) -and -not [string]::IsNullOrWhiteSpace($env:GOOGLE_APPLICATION_CREDENTIALS) -and (Test-Path $env:GOOGLE_APPLICATION_CREDENTIALS)) {
    try {
      gcloud auth activate-service-account --key-file=$env:GOOGLE_APPLICATION_CREDENTIALS --quiet 1>$null 2>$null
    } catch {}
    try {
      $activeAccount = (gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>$null | Select-Object -First 1).Trim()
    } catch {
      $activeAccount = ""
    }
  }

  if ([string]::IsNullOrWhiteSpace($activeAccount)) {
    if ($hasAuthHint) {
      Fail "gcp: credentials configured but no active gcloud auth session"
      return @{ status = "fail" }
    }
    Skip "gcp: no active gcloud auth session"
    return @{ status = "skip" }
  }

  $project = $env:GOOGLE_CLOUD_PROJECT
  if ([string]::IsNullOrWhiteSpace($project)) {
    try {
      $project = (gcloud config get-value project 2>$null).Trim()
    } catch {
      $project = ""
    }
  }
  if ([string]::IsNullOrWhiteSpace($project) -or $project -eq "(unset)") {
    Fail "gcp: authenticated but no project configured (set GOOGLE_CLOUD_PROJECT or gcloud config project)"
    return @{ status = "fail" }
  }

  $raw = $null
  try {
    $raw = gcloud compute instances list --project $project --format=json 2>$null
  } catch {
    Fail "gcp: failed to list compute instances for project $project"
    return @{ status = "fail" }
  }

  $instances = @()
  if (-not [string]::IsNullOrWhiteSpace($raw)) {
    $instances = $raw | ConvertFrom-Json
  }

  $stateCounts = @{}
  foreach ($instance in $instances) {
    $state = if ($instance.status) { $instance.status } else { "unknown" }
    if (-not $stateCounts.ContainsKey($state)) { $stateCounts[$state] = 0 }
    $stateCounts[$state]++
  }

  Pass "gcp: listed $($instances.Count) instances in project $project; state distribution: $($stateCounts | ConvertTo-Json -Compress)"
  return @{ status = "pass" }
}

function Get-OvhBaseUrl {
  $endpoint = if ($env:OVH_ENDPOINT) { $env:OVH_ENDPOINT } else { "ovh-eu" }
  if ($endpoint -match '^https?://') {
    return $endpoint.TrimEnd('/')
  }

  switch ($endpoint) {
    "ovh-us" { return "https://api.us.ovhcloud.com/1.0" }
    "ovh-ca" { return "https://ca.api.ovh.com/1.0" }
    default  { return "https://eu.api.ovh.com/1.0" }
  }
}

function Get-Sha1Hex([string]$Value) {
  $sha1 = [System.Security.Cryptography.SHA1]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
    $hash = $sha1.ComputeHash($bytes)
    return -join ($hash | ForEach-Object { $_.ToString("x2") })
  } finally {
    $sha1.Dispose()
  }
}

function Invoke-OvhSignedGet {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$BaseUrl
  )

  $url = "$BaseUrl$Path"
  $timestamp = (Invoke-RestMethod -Method Get -Uri "$BaseUrl/auth/time").ToString()
  $payload = "$($env:OVH_APPLICATION_SECRET)+$($env:OVH_CONSUMER_KEY)+GET+$url++$timestamp"
  $digest = Get-Sha1Hex $payload
  $signature = "`$1`$$digest"

  return Invoke-RestMethod -Method Get -Uri $url -Headers @{
    "X-Ovh-Application" = $env:OVH_APPLICATION_KEY
    "X-Ovh-Consumer"    = $env:OVH_CONSUMER_KEY
    "X-Ovh-Timestamp"   = $timestamp
    "X-Ovh-Signature"   = $signature
    "Content-Type"      = "application/json"
  }
}

function Test-Ovh {
  if (-not (Load-ProviderProfile -Provider "ovh")) {
    Fail "ovh: unable to resolve the selected profile"
    return @{ status = "fail" }
  }

  if ([string]::IsNullOrWhiteSpace($env:OVH_APPLICATION_KEY) -or [string]::IsNullOrWhiteSpace($env:OVH_APPLICATION_SECRET) -or [string]::IsNullOrWhiteSpace($env:OVH_CONSUMER_KEY)) {
    Skip "ovh: credentials not configured (OVH_APPLICATION_KEY/OVH_APPLICATION_SECRET/OVH_CONSUMER_KEY)"
    return @{ status = "skip" }
  }

  $baseUrl = Get-OvhBaseUrl

  $services = $null
  try {
    $services = Invoke-OvhSignedGet -Path "/vps" -BaseUrl $baseUrl
  } catch {
    Fail "ovh: failed to list VPS services from $baseUrl"
    return @{ status = "fail" }
  }

  $serviceList = @($services)
  if ($serviceList.Count -eq 0) {
    Pass "ovh: listed 0 VPS services"
    return @{ status = "pass" }
  }

  $stateCounts = @{}
  foreach ($service in $serviceList) {
    $encoded = [System.Uri]::EscapeDataString([string]$service)
    $detail = $null
    try {
      $detail = Invoke-OvhSignedGet -Path "/vps/$encoded" -BaseUrl $baseUrl
    } catch {
      Fail "ovh: failed to fetch details for VPS service $service"
      return @{ status = "fail" }
    }

    $state = if ($detail.state) { $detail.state } elseif ($detail.status) { $detail.status } else { "unknown" }
    if (-not $stateCounts.ContainsKey($state)) { $stateCounts[$state] = 0 }
    $stateCounts[$state]++
  }

  Pass "ovh: listed $($serviceList.Count) VPS services; state distribution: $($stateCounts | ConvertTo-Json -Compress)"
  return @{ status = "pass" }
}

function Test-Azure {
  if (-not (Load-ProviderProfile -Provider "azure")) {
    Fail "azure: unable to resolve the selected profile"
    return @{ status = "fail" }
  }

  $clientId = if ($env:AZURE_CLIENT_ID) { $env:AZURE_CLIENT_ID } else { $env:ARM_CLIENT_ID }
  $tenantId = if ($env:AZURE_TENANT_ID) { $env:AZURE_TENANT_ID } else { $env:ARM_TENANT_ID }
  $clientSecret = if ($env:AZURE_CLIENT_SECRET) { $env:AZURE_CLIENT_SECRET } else { $env:ARM_CLIENT_SECRET }
  $subscriptionId = if ($env:AZURE_SUBSCRIPTION_ID) { $env:AZURE_SUBSCRIPTION_ID } else { $env:ARM_SUBSCRIPTION_ID }
  $hasSpHint = -not [string]::IsNullOrWhiteSpace($clientId) -and -not [string]::IsNullOrWhiteSpace($tenantId) -and -not [string]::IsNullOrWhiteSpace($clientSecret)

  if (-not $hasSpHint -and [string]::IsNullOrWhiteSpace($subscriptionId) -and -not $script:UseLocalSessions) {
    Skip "azure: skipped (no selected profile credentials; set REGRESSION_USE_LOCAL_SESSIONS=true to use local CLI sessions)"
    return @{ status = "skip" }
  }

  if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    if ($hasSpHint) {
      Fail "azure: service principal credentials are present but az CLI is missing"
      return @{ status = "fail" }
    }
    Skip "azure: az CLI not installed and no Azure credentials configured"
    return @{ status = "skip" }
  }

  try {
    az account show 1>$null 2>$null
  } catch {
    if ($hasSpHint) {
      try {
        az login --service-principal --username $clientId --password $clientSecret --tenant $tenantId --output none 1>$null 2>$null
      } catch {
        Fail "azure: service principal login failed"
        return @{ status = "fail" }
      }
    } else {
      Skip "azure: no active az login session"
      return @{ status = "skip" }
    }
  }

  if (-not [string]::IsNullOrWhiteSpace($subscriptionId)) {
    try {
      az account set --subscription $subscriptionId 1>$null 2>$null
    } catch {
      Fail "azure: failed to select subscription $subscriptionId"
      return @{ status = "fail" }
    }
  }

  $raw = $null
  try {
    $raw = az vm list -d --output json 2>$null
  } catch {
    Fail "azure: failed to list virtual machines"
    return @{ status = "fail" }
  }

  $vms = @()
  if (-not [string]::IsNullOrWhiteSpace($raw)) {
    $vms = $raw | ConvertFrom-Json
  }

  $stateCounts = @{}
  foreach ($vm in $vms) {
    $state = if ($vm.powerState) { $vm.powerState } else { "unknown" }
    if (-not $stateCounts.ContainsKey($state)) { $stateCounts[$state] = 0 }
    $stateCounts[$state]++
  }

  Pass "azure: listed $($vms.Count) VMs; power-state distribution: $($stateCounts | ConvertTo-Json -Compress)"
  return @{ status = "pass" }
}

Write-Host "Running provider regression checks (read/list only)..."

Invoke-ProviderTest -Provider "hostinger" -Test ${function:Test-Hostinger}
Invoke-ProviderTest -Provider "contabo" -Test ${function:Test-Contabo}
Invoke-ProviderTest -Provider "aws" -Test ${function:Test-Aws}
Invoke-ProviderTest -Provider "gcp" -Test ${function:Test-Gcp}
Invoke-ProviderTest -Provider "azure" -Test ${function:Test-Azure}
Invoke-ProviderTest -Provider "ovh" -Test ${function:Test-Ovh}

Write-Host ""
Write-Host "Summary: pass=$PassCount skip=$SkipCount fail=$FailCount"

if ($FailCount -gt 0) {
  Write-Host "Failed providers: $($FailedProviders -join ', ')"
  exit 1
}
