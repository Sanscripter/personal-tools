param(
    [switch]$Status
)

$ErrorActionPreference = 'Stop'
$tool = Join-Path $PSScriptRoot '..\..\scripts\system\keyboard-language.ps1'

if ($Status) {
    & $tool status
    exit $LASTEXITCODE
}

Write-Host 'Keyboard language setup' -ForegroundColor Cyan
Write-Host 'Ensuring Portuguese and English International are ready...' -ForegroundColor Green

& $tool install 'portuguese'
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

& $tool install 'english international'
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

& $tool set 'portuguese'
exit $LASTEXITCODE
