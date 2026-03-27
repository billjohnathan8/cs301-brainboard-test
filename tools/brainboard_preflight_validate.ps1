param(
    [switch]$SkipGenerate,
    [switch]$NoUpgrade,
    [switch]$StrictOpenTofu
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$importDir = Join-Path $repoRoot "brainboard-import"
$flattenScript = Join-Path $repoRoot "tools\\brainboard_flatten.py"

if (-not (Test-Path -LiteralPath $flattenScript)) {
    throw "Missing flatten script: $flattenScript"
}

if (-not $SkipGenerate) {
    Write-Host "[preflight] Regenerating brainboard import file..."
    & python $flattenScript --skip-static-analysis --skip-checkov
    if ($LASTEXITCODE -ne 0) {
        throw "Flatten generation failed with exit code $LASTEXITCODE."
    }
}

if (-not (Test-Path -LiteralPath (Join-Path $importDir "brainboard.tf"))) {
    throw "Missing generated file: $importDir\\brainboard.tf"
}

$tool = $null
foreach ($candidate in @("opentofu", "tofu")) {
    if (Get-Command $candidate -ErrorAction SilentlyContinue) {
        $tool = $candidate
        break
    }
}

if (-not $tool -and $env:LOCALAPPDATA) {
    $wingetTofu = Join-Path $env:LOCALAPPDATA "Microsoft\\WinGet\\Packages\\OpenTofu.Tofu_Microsoft.Winget.Source_8wekyb3d8bbwe\\tofu.exe"
    if (Test-Path -LiteralPath $wingetTofu) {
        $tool = $wingetTofu
    }
}

if (-not $tool) {
    if ($StrictOpenTofu) {
        throw "OpenTofu CLI not found. Install 'opentofu' (or 'tofu') and retry."
    }
    if (Get-Command terraform -ErrorAction SilentlyContinue) {
        $tool = "terraform"
        Write-Warning "OpenTofu not found. Falling back to Terraform for local preflight."
    } else {
        throw "No IaC CLI found. Install OpenTofu ('opentofu' or 'tofu') or Terraform."
    }
}

Write-Host "[preflight] Using CLI: $tool"

$initArgs = @("init", "-input=false", "-force-copy")
if (-not $NoUpgrade) {
    $initArgs += "-upgrade=true"
}

Write-Host "[preflight] Running init in $importDir ..."
Push-Location $importDir
try {
    & $tool @initArgs
    if ($LASTEXITCODE -ne 0) {
        throw "$tool init failed with exit code $LASTEXITCODE."
    }

    Write-Host "[preflight] Running validate in $importDir ..."
    & $tool "validate"
    if ($LASTEXITCODE -ne 0) {
        throw "$tool validate failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

Write-Host "[preflight] SUCCESS: brainboard-import validation passed."
