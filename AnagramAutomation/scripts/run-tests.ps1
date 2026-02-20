param(
    [string]$Tag
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot   # AnagramAutomation/
$workspace = Split-Path -Parent $root       # repo root

$webValidatorProject = Join-Path $root "AnagramWebValidator\AnagramWebValidator.csproj"
$testProject  = Join-Path $root "AnagramAutomation.csproj"
$trxOut       = Join-Path $root "TestResults\anagram-results.trx"
$htmlOut      = Join-Path $root "TestResults\AnagramExtentReport.html"
$ps1Report    = Join-Path $root "tools\TrxToExtent\TrxToExtent.ps1"

$webValidatorProcess = $null

# Kill any leftover process on port 5000 from a previous run
$existing = Get-NetTCPConnection -LocalPort 5000 -State Listen -ErrorAction SilentlyContinue
if ($existing) {
    $proc = Get-Process -Id $existing.OwningProcess -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Host "Killing leftover process on port 5000 (PID $($proc.Id))..." -ForegroundColor Yellow
        $proc | Stop-Process -Force
        Start-Sleep -Seconds 1
    }
}

try {
    # --- 1. Start AnagramWebValidator (dotnet run builds automatically if needed) ---
    Write-Host "`n[1/4] Starting AnagramWebValidator on http://localhost:5000 ..." -ForegroundColor Cyan
    $webValidatorProcess = Start-Process dotnet `
        -ArgumentList "run --project `"$webValidatorProject`"" `
        -PassThru -WindowStyle Hidden

    # Wait until API responds (up to 30s)
    $ready    = $false
    $deadline = (Get-Date).AddSeconds(30)
    while ((Get-Date) -lt $deadline) {
        try {
            Invoke-WebRequest -Uri "http://localhost:5000/" -UseBasicParsing -ErrorAction Stop | Out-Null
            Write-Host "  API is ready!" -ForegroundColor Green
            $ready = $true
            break
        } catch {
            Start-Sleep -Milliseconds 500
        }
    }
    if (-not $ready) { Write-Warning "API did not respond within 30s - API test may fail" }

    # --- 2. Run tests ---
    Write-Host "`n[2/4] Running tests..." -ForegroundColor Cyan
    if (Test-Path $trxOut) {
        Remove-Item -Path $trxOut -Force -ErrorAction SilentlyContinue
    }

    $dotnetArgs = @(
        "test"
        $testProject
        "--logger"
        "trx;LogFileName=anagram-results.trx"
    )

    if ($Tag -and $Tag.Trim().Length -gt 0) {
        $normalizedTag = $Tag.Trim().TrimStart('@')
        Write-Host "  Applying tag filter: @$normalizedTag" -ForegroundColor Yellow
        $dotnetArgs += @("--filter", "TestCategory=$normalizedTag")
    }

    & dotnet @dotnetArgs
    $testExit = $LASTEXITCODE

} finally {
    # --- Stop AnagramWebValidator regardless of test outcome ---
    if ($webValidatorProcess -and -not $webValidatorProcess.HasExited) {
        Write-Host "`nStopping AnagramWebValidator..." -ForegroundColor DarkGray
        Stop-Process -Id $webValidatorProcess.Id -Force -ErrorAction SilentlyContinue
        $webValidatorProcess.Dispose()
    }
}

# --- Clean up auto-generated timestamped TRX files from Test Explorer ---
Get-ChildItem -Path (Join-Path $root "TestResults") -Filter "*.trx" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne "anagram-results.trx" } |
    Remove-Item -Force -ErrorAction SilentlyContinue

# --- 3. Generate + open report ---
Write-Host "`n[3/4] Generating Extent report..." -ForegroundColor Cyan
if (Test-Path $trxOut) {
    & $ps1Report -Trx $trxOut -Out $htmlOut
    Start-Process $htmlOut
}
else {
    Write-Warning "No TRX results were produced (test run likely failed before execution). Skipping report generation."
}

exit $testExit
