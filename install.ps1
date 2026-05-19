# =============================================================================
# INSTALL - run on TARGET PC (RTX 3090 / 64GB RAM)
# =============================================================================
# Prereqs: copy this entire folder to target PC, run from PowerShell.
# Net access needed only for Aider pip install (one-time).
# =============================================================================

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"

$Root      = $PSScriptRoot
$BinDir    = Join-Path $Root "bin"
$ModelsDir = Join-Path $Root "models"
$InstDir   = Join-Path $Root "installers"
$VenvDir   = Join-Path $Root ".venv"
$Zip       = Join-Path $InstDir "ollama-windows-amd64.zip"
$Ollama    = Join-Path $BinDir "ollama.exe"

function W-Step($m) { Write-Host "`n[STEP] $m" -ForegroundColor Cyan }
function W-OK($m)   { Write-Host "  [OK] $m"   -ForegroundColor Green }
function W-Warn($m) { Write-Host "  [!!] $m"   -ForegroundColor Yellow }
function W-Err($m)  { Write-Host "  [ERR] $m"  -ForegroundColor Red }

function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [Environment]::GetEnvironmentVariable("Path","User")
}

Write-Host "==========================================" -ForegroundColor Magenta
Write-Host "  INSTALL on TARGET PC" -ForegroundColor Magenta
Write-Host "==========================================" -ForegroundColor Magenta

# --- Pre-flight checks -------------------------------------------------------
if (-not (Test-Path $ModelsDir) -or
    -not (Get-ChildItem $ModelsDir -ErrorAction SilentlyContinue)) {
    W-Err "models/ empty. Run build.ps1 on source PC first and copy this folder over."
    exit 1
}

# --- 1. Portable Ollama extract ---------------------------------------------
W-Step "1/4 Portable Ollama"
if (-not (Test-Path $Ollama)) {
    if (-not (Test-Path $Zip)) {
        W-Warn "ollama zip missing; downloading..."
        New-Item -ItemType Directory -Force -Path $InstDir | Out-Null
        $url = (Invoke-RestMethod "https://api.github.com/repos/ollama/ollama/releases/latest").assets |
               Where-Object { $_.name -eq "ollama-windows-amd64.zip" } |
               Select-Object -ExpandProperty browser_download_url
        Invoke-WebRequest -Uri $url -OutFile $Zip
    }
    Expand-Archive -Path $Zip -DestinationPath $BinDir -Force
}
if (-not (Test-Path $Ollama)) { W-Err "ollama.exe missing"; exit 1 }
W-OK "ollama.exe present"

# --- 2. Start portable Ollama service ---------------------------------------
W-Step "2/4 Start Ollama service"
Get-Process ollama -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

$env:OLLAMA_MODELS = $ModelsDir
$env:OLLAMA_HOST   = "127.0.0.1:11434"
Start-Process -FilePath $Ollama -ArgumentList "serve" -WindowStyle Hidden
Start-Sleep -Seconds 4

$list = & $Ollama list 2>&1
Write-Host $list
if ($list -notmatch "qwen2\.5-coder") {
    W-Err "Models not detected. Check models/ folder integrity."
    exit 1
}
W-OK "Models loaded"

# --- 3. Python venv + Aider --------------------------------------------------
W-Step "3/4 Python venv + Aider (requires 64-bit Python 3.10+)"

# Find a usable 64-bit Python interpreter
function Get-Py64 {
    # Prefer py launcher (can pick 64-bit explicitly)
    $candidates = @()
    if (Get-Command py -ErrorAction SilentlyContinue) {
        foreach ($v in @("3.12","3.13","3.11","3.10")) {
            $arch = (& py "-$v" -c "import platform; print(platform.architecture()[0])" 2>$null)
            if ($arch -eq "64bit") { $candidates += "py -$v" }
        }
    }
    if (Get-Command python -ErrorAction SilentlyContinue) {
        $arch = (& python -c "import platform; print(platform.architecture()[0])" 2>$null)
        if ($arch -eq "64bit") { $candidates += "python" }
    }
    return $candidates | Select-Object -First 1
}

# Aider 0.86.x requires Python >=3.10,<3.13 -- enforce 3.10/3.11/3.12 only
function Get-PyAider {
    $candidates = @()
    if (Get-Command py -ErrorAction SilentlyContinue) {
        foreach ($v in @("3.12","3.11","3.10")) {
            $arch = (& py "-$v" -c "import platform; print(platform.architecture()[0])" 2>$null)
            if ($arch -eq "64bit") { $candidates += "py -$v" }
        }
    }
    return $candidates | Select-Object -First 1
}

$pyCmd = Get-PyAider
if (-not $pyCmd) {
    W-Warn "No suitable Python (3.10-3.12 64-bit) found."
    $bundledPyInstaller = Join-Path $InstDir "python-3.12.7-amd64.exe"
    if (Test-Path $bundledPyInstaller) {
        W-Warn "Running bundled Python 3.12 installer (UAC prompt will appear -- click Yes)..."
        $py312Target = Join-Path $env:LOCALAPPDATA "Programs\Python\Python312"
        $args = @("/passive","InstallAllUsers=0","PrependPath=1","Include_test=0","Include_launcher=1","TargetDir=$py312Target")
        $proc = Start-Process -FilePath $bundledPyInstaller -ArgumentList $args -Wait -PassThru
        if ($proc.ExitCode -ne 0) {
            W-Err "Python 3.12 install failed (ExitCode=$($proc.ExitCode))."
            W-Err "Install manually from $bundledPyInstaller and rerun."
            exit 1
        }
        Refresh-Path
        $pyCmd = Get-PyAider
    } else {
        W-Err "Bundled Python installer missing at $bundledPyInstaller"
        W-Err "Install Python 3.12 64-bit from https://python.org/downloads and rerun."
        exit 1
    }
}
if (-not $pyCmd) {
    W-Err "Python 3.10-3.12 64-bit required for Aider. Install manually and rerun."
    exit 1
}
W-OK "Using interpreter: $pyCmd"

if (-not (Test-Path $VenvDir)) {
    # Split command for splatting (e.g. "py -3.12")
    $parts = $pyCmd.Split(' ')
    & $parts[0] @($parts[1..($parts.Length-1)]) -m venv $VenvDir
}

$pip   = Join-Path $VenvDir "Scripts\pip.exe"
$pyExe = Join-Path $VenvDir "Scripts\python.exe"
& $pyExe -m pip install --upgrade pip --quiet
# Python 3.13+ venvs ship without setuptools/wheel; some Aider deps build from source
& $pip install --upgrade setuptools wheel --quiet
& $pip install --upgrade aider-chat --quiet
if ($LASTEXITCODE -ne 0) { W-Err "Aider pip install failed"; exit 1 }
W-OK "Aider ready"

# --- 4. Smoke test -----------------------------------------------------------
W-Step "4/4 Smoke test"
$out = & $Ollama run qwen2.5-coder:32b "Reply only: READY" 2>&1
if ($out -match "READY") { W-OK "Inference works (32B model)" }
else { W-Warn "Smoke test response:`n$out" }

# --- Done --------------------------------------------------------------------
Write-Host "`n==========================================" -ForegroundColor Green
Write-Host "  INSTALL COMPLETE" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Run:   $Root\agent.bat" -ForegroundColor White
Write-Host "  Or add this folder to PATH for global 'agent' command." -ForegroundColor White
