<#
  Starts the ManoFit backends and (by default) a Cloudflare quick tunnel for
  each, so a phone on its own internet can reach them.

    .\start-backends.ps1          # ml_service + tara_service + 2 HTTPS tunnels
    .\start-backends.ps1 -Lan     # no tunnels; prints http://<lan-ip>:8000 / :3000
                                  # (Tara voice mic will NOT work over plain http)

  Leave this window open. Ctrl+C stops everything it started.
#>
param([switch]$Lan)

$ErrorActionPreference = 'Stop'
$root      = Split-Path $PSScriptRoot -Parent            # ...\SIH-2026
$mlDir     = Join-Path $root 'ml_service'
$taraDir   = Join-Path $root 'tara_service'
$jobs      = @()

function Stop-All {
  Write-Host "`nStopping backends..." -ForegroundColor Yellow
  foreach ($j in $jobs) { if ($j) { Stop-Job $j -ErrorAction SilentlyContinue; Remove-Job $j -Force -ErrorAction SilentlyContinue } }
  Get-Process cloudflared -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
trap { Stop-All; break }

# --- checks -----------------------------------------------------------------
if (-not (Test-Path (Join-Path $taraDir '.env'))) {
  Write-Warning "tara_service\.env missing — copy .env.example and add GEMINI_API_KEY. Tara will not start without it."
}
$py = (Get-Command python -ErrorAction SilentlyContinue).Source
if (-not $py) { throw "python not found on PATH." }
$node = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $node) { throw "node not found on PATH." }
$cf = (Get-Command cloudflared -ErrorAction SilentlyContinue).Source
if (-not $Lan -and -not $cf) {
  throw "cloudflared not found. Install it (winget install --id Cloudflare.cloudflared -e) or run with -Lan."
}

# --- ml_service (uvicorn 0.0.0.0:8000) ------------------------------------
Write-Host "Starting ml_service on :8000 ..." -ForegroundColor Cyan
$jobs += Start-Job -Name ml -ScriptBlock {
  param($dir) Set-Location $dir; python run_server.py
} -ArgumentList $mlDir

# --- tara_service (node 0.0.0.0:3000) -----------------------------------
Write-Host "Starting tara_service on :3000 ..." -ForegroundColor Cyan
$jobs += Start-Job -Name tara -ScriptBlock {
  param($dir) Set-Location $dir; npm start
} -ArgumentList $taraDir

Start-Sleep -Seconds 4

function Sync-EndpointsToSupabase($rawMl, $rawTara) {
  $envPath = Join-Path $root '.env'
  if (-not (Test-Path $envPath)) { return }
  $envContent = Get-Content $envPath
  $sbUrl = ''
  $sbKey = ''
  foreach ($line in $envContent) {
    if ($line -match '^\s*SUPABASE_URL\s*=\s*(.+)$') { $sbUrl = $Matches[1].Trim().Trim('"').Trim("'") }
    if ($line -match '^\s*SUPABASE_ANON_KEY\s*=\s*(.+)$') { $sbKey = $Matches[1].Trim().Trim('"').Trim("'") }
  }
  if (-not $sbUrl -or -not $sbKey) { return }

  $sbUrl = $sbUrl -replace '/rest/v1/?$', ''
  $sbUrl = $sbUrl.TrimEnd('/')

  $headers = @{
    "apikey" = $sbKey
    "Authorization" = "Bearer $sbKey"
    "Content-Type" = "application/json"
    "Prefer" = "resolution=merge-duplicates"
  }
  $body = @(
    @{ key = "ml_url"; value = $rawMl },
    @{ key = "tara_url"; value = $rawTara }
  ) | ConvertTo-Json -Compress

  try {
    $null = Invoke-RestMethod -Uri "$sbUrl/rest/v1/system_config" -Headers $headers -Method Post -Body $body
    Write-Host "`n=== Dynamic Supabase Service Discovery ===" -ForegroundColor Green
    Write-Host "[OK] Live ML and Tara URLs synced to Supabase successfully!" -ForegroundColor Green
    Write-Host "     Mobile app will connect automatically: no manual pasting required.`n" -ForegroundColor Cyan
  } catch {
    $err = $_.Exception.Message
    if ($err -match '404|PGRST205') {
      Write-Host "`n[NOTE] Supabase table 'system_config' not found yet." -ForegroundColor Yellow
      Write-Host "       Run the 1-time script 'SIH-2026\supabase_migration_system_config.sql' in your Supabase SQL Editor`n" -ForegroundColor Yellow
    } else {
      Write-Warning "Could not sync endpoints to Supabase: $err"
    }
  }
}


if ($Lan) {
  $ip = (Get-NetIPAddress -AddressFamily IPv4 |
         Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.)' -and $_.PrefixOrigin -ne 'WellKnown' } |
         Select-Object -First 1).IPAddress
  $lanMl = "http://$ip`:8000"
  $lanTara = "http://$ip`:3000"
  Write-Host "`n=== LAN mode (same Wi-Fi only) ===" -ForegroundColor Green
  Write-Host "ML   : $lanMl"
  Write-Host "Tara : $lanTara   (text chat only — mic needs HTTPS)"
  Sync-EndpointsToSupabase $lanMl $lanTara
} else {
  function Start-Tunnel($port) {
    $log = Join-Path $env:TEMP "manofit-cf-$port.log"
    if (Test-Path $log) { Remove-Item $log -Force }
    Start-Process -FilePath $cf -WindowStyle Hidden `
      -ArgumentList "tunnel --no-autoupdate --url http://localhost:$port" `
      -RedirectStandardError $log -RedirectStandardOutput "$log.out"
    $url = $null
    for ($i = 0; $i -lt 30 -and -not $url; $i++) {
      Start-Sleep -Seconds 1
      $txt = (Get-Content $log, "$log.out" -Raw -ErrorAction SilentlyContinue)
      if ($txt -match 'https://[a-z0-9-]+\.trycloudflare\.com') { $url = $Matches[0] }
    }
    return $url
  }
  Write-Host "`nOpening HTTPS tunnels..." -ForegroundColor Cyan
  $mlUrl   = Start-Tunnel 8000
  $taraUrl = Start-Tunnel 3000
  Write-Host "`n=== Live Service URLs ===" -ForegroundColor Green
  Write-Host ("ML   : " + ($mlUrl ?? "(tunnel failed)"))
  Write-Host ("Tara : " + ($taraUrl ?? "(tunnel failed)"))

  if ($mlUrl -and $taraUrl) {
    Sync-EndpointsToSupabase $mlUrl $taraUrl
  }
}

Write-Host "`nRunning. Ctrl+C to stop.`n" -ForegroundColor DarkGray
try   { while ($true) { Start-Sleep -Seconds 3600 } }
finally { Stop-All }

