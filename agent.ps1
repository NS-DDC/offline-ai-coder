# =============================================================================
# Offline AI Coding Agent - Launcher (fully portable)
# =============================================================================
# Usage:
#   agent.ps1                 default: qwen2.5-coder:32b
#   agent.ps1 --fast          qwen2.5-coder:14b
#   agent.ps1 --tiny          qwen2.5-coder:7b
#   agent.ps1 --model X       any local Ollama model
#   agent.ps1 file1 file2     pass files to Aider
# =============================================================================

$ErrorActionPreference = "Stop"

$Root      = $PSScriptRoot
$BinDir    = Join-Path $Root "bin"
$ModelsDir = Join-Path $Root "models"
$Ollama    = Join-Path $BinDir "ollama.exe"
$VenvAider = Join-Path $Root ".venv\Scripts\aider.exe"
$ConfFile  = Join-Path $Root ".aider.conf.yml"

$ModelDefault = "ollama_chat/qwen2.5-coder:32b"
$ModelFast    = "ollama_chat/qwen2.5-coder:14b"
$ModelTiny    = "ollama_chat/qwen2.5-coder:7b"

# --- Parse args --------------------------------------------------------------
$model = $ModelDefault
$pass  = @()
for ($i = 0; $i -lt $args.Count; $i++) {
    switch -Regex ($args[$i]) {
        '^--fast$'  { $model = $ModelFast; continue }
        '^--tiny$'  { $model = $ModelTiny; continue }
        '^--model$' { $i++; $model = $args[$i]; continue }
        default     { $pass += $args[$i] }
    }
}

# --- Sanity ------------------------------------------------------------------
if (-not (Test-Path $Ollama))    { Write-Host "[ERR] bin/ollama.exe missing. Run install.ps1." -ForegroundColor Red; exit 1 }
if (-not (Test-Path $VenvAider)) { Write-Host "[ERR] .venv missing. Run install.ps1."          -ForegroundColor Red; exit 1 }

# --- Portable env ------------------------------------------------------------
$env:OLLAMA_MODELS         = $ModelsDir
$env:OLLAMA_HOST           = "127.0.0.1:11434"
$env:OLLAMA_API_BASE       = "http://127.0.0.1:11434"
$env:OLLAMA_CONTEXT_LENGTH = "32768"

# --- Start service if absent OR if running on different models path ----------
$svc = Get-Process ollama -ErrorAction SilentlyContinue
if (-not $svc) {
    Start-Process -FilePath $Ollama -ArgumentList "serve" -WindowStyle Hidden
    Start-Sleep -Seconds 2
}

# --- Quick liveness check ----------------------------------------------------
try {
    $null = Invoke-RestMethod "http://127.0.0.1:11434/api/tags" -TimeoutSec 5
} catch {
    Write-Host "[!!] Ollama not responding, restarting..." -ForegroundColor Yellow
    Get-Process ollama -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2
    Start-Process -FilePath $Ollama -ArgumentList "serve" -WindowStyle Hidden
    Start-Sleep -Seconds 4
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Offline AI Agent  |  $model" -ForegroundColor Cyan
Write-Host "  Models: $ModelsDir" -ForegroundColor DarkGray
Write-Host "==========================================" -ForegroundColor Cyan

& $VenvAider --model $model --config $ConfFile @pass
