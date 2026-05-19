# =============================================================================
# BUILD - run on this PC. Produces a fully portable folder.
# =============================================================================
# 1. Extract portable Ollama (no install needed)
# 2. Pull models into local ./models/
# 3. Result: copy entire folder to target PC, run install.ps1 there
# =============================================================================

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"

$Root      = $PSScriptRoot
$BinDir    = Join-Path $Root "bin"
$ModelsDir = Join-Path $Root "models"
$InstDir   = Join-Path $Root "installers"
$Zip       = Join-Path $InstDir "ollama-windows-amd64.zip"
$Ollama    = Join-Path $BinDir "ollama.exe"

$Models = @(
    "qwen2.5-coder:32b",
    "qwen2.5-coder:14b",
    "qwen2.5-coder:7b",
    "nomic-embed-text"
)

function W-Step($m) { Write-Host "`n[STEP] $m" -ForegroundColor Cyan }
function W-OK($m)   { Write-Host "  [OK] $m"   -ForegroundColor Green }
function W-Warn($m) { Write-Host "  [!!] $m"   -ForegroundColor Yellow }
function W-Err($m)  { Write-Host "  [ERR] $m"  -ForegroundColor Red }

Write-Host "==========================================" -ForegroundColor Magenta
Write-Host "  BUILD (this PC)" -ForegroundColor Magenta
Write-Host "==========================================" -ForegroundColor Magenta

New-Item -ItemType Directory -Force -Path $BinDir,$ModelsDir,$InstDir | Out-Null

# --- 1. Portable Ollama binary -----------------------------------------------
W-Step "1/3 Extract portable Ollama"
if (-not (Test-Path $Zip)) {
    W-Warn "Zip missing, downloading..."
    $url = (Invoke-RestMethod "https://api.github.com/repos/ollama/ollama/releases/latest").assets |
           Where-Object { $_.name -eq "ollama-windows-amd64.zip" } |
           Select-Object -ExpandProperty browser_download_url
    Invoke-WebRequest -Uri $url -OutFile $Zip
}
if (-not (Test-Path $Ollama)) {
    Expand-Archive -Path $Zip -DestinationPath $BinDir -Force
}
if (-not (Test-Path $Ollama)) {
    W-Err "ollama.exe not found after extraction"
    exit 1
}
W-OK "ollama.exe ready: $Ollama"

# --- 2. Start portable Ollama service ----------------------------------------
W-Step "2/3 Start portable Ollama service"
# Kill any existing Ollama (could be from prior install)
Get-Process ollama -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

$env:OLLAMA_MODELS = $ModelsDir
$env:OLLAMA_HOST   = "127.0.0.1:11434"
Start-Process -FilePath $Ollama -ArgumentList "serve" -WindowStyle Hidden
Start-Sleep -Seconds 4
W-OK "Service up. OLLAMA_MODELS=$ModelsDir"

# --- 3. Pull models ----------------------------------------------------------
W-Step "3/3 Pull models (~35GB total, can take a while)"
foreach ($m in $Models) {
    Write-Host "`n  -> $m" -ForegroundColor Yellow
    & $Ollama pull $m
    if ($LASTEXITCODE -ne 0) {
        W-Err "Pull failed: $m (continuing)"
    } else {
        W-OK "Pulled $m"
    }
}

# --- Summary -----------------------------------------------------------------
$sz = (Get-ChildItem $ModelsDir -Recurse -File -ErrorAction SilentlyContinue |
       Measure-Object Length -Sum).Sum / 1GB

Write-Host "`n==========================================" -ForegroundColor Green
Write-Host "  BUILD COMPLETE" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ("  Models size: {0:N1} GB" -f $sz) -ForegroundColor White
Write-Host  "  Next: copy this folder to target PC, run install.ps1" -ForegroundColor White
