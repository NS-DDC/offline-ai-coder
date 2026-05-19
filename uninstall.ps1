# =============================================================================
# Uninstall - removes generated artifacts (NOT the source scripts)
# Since this package is fully portable, "uninstall" mostly means delete folder.
# =============================================================================

$ErrorActionPreference = "Continue"

$Root      = $PSScriptRoot
$VenvDir   = Join-Path $Root ".venv"
$BinDir    = Join-Path $Root "bin"
$ModelsDir = Join-Path $Root "models"

function Ask($q) { (Read-Host "$q [y/N]") -match '^[yY]' }

Write-Host "==========================================" -ForegroundColor Yellow
Write-Host "  Uninstall (portable agent)" -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Yellow

# Stop running ollama from this folder
$proc = Get-Process ollama -ErrorAction SilentlyContinue
if ($proc) {
    foreach ($p in $proc) {
        try {
            if ($p.Path -and $p.Path.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)) {
                $p | Stop-Process -Force
                Write-Host "  Stopped Ollama: $($p.Id)" -ForegroundColor Green
            }
        } catch {}
    }
}

if (Test-Path $VenvDir) {
    if (Ask "Remove .venv (Aider Python env) ?") {
        Remove-Item -Recurse -Force $VenvDir
        Write-Host "  [OK] .venv removed" -ForegroundColor Green
    }
}

if (Test-Path $BinDir) {
    if (Ask "Remove bin/ (portable Ollama binary) ?") {
        Remove-Item -Recurse -Force $BinDir
        Write-Host "  [OK] bin/ removed" -ForegroundColor Green
    }
}

if (Test-Path $ModelsDir) {
    if (Ask "Remove models/ (~35GB) ?") {
        Remove-Item -Recurse -Force $ModelsDir
        Write-Host "  [OK] models/ removed" -ForegroundColor Green
    }
}

# Remove user env var if it points at our models dir
$userOllamaModels = [Environment]::GetEnvironmentVariable("OLLAMA_MODELS","User")
if ($userOllamaModels -and $userOllamaModels.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)) {
    if (Ask "Remove OLLAMA_MODELS user env var (was $userOllamaModels)?") {
        [Environment]::SetEnvironmentVariable("OLLAMA_MODELS", $null, "User")
        Write-Host "  [OK] env var cleared" -ForegroundColor Green
    }
}

Write-Host "`nDone. Scripts (build/install/agent/README) preserved." -ForegroundColor Cyan
Write-Host "Delete the whole folder for full cleanup." -ForegroundColor Cyan
