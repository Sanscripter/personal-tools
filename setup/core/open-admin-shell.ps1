param(
    [ValidateSet('powershell', 'cmd')]
    [string]$Shell = 'powershell',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'setup-utils.ps1')

$currentPath = (Get-Location).Path
Write-Host ''
Write-Host '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!' -ForegroundColor Yellow
Write-Host '!! ADMINISTRATOR SHELL REQUESTED                        !!' -ForegroundColor Yellow
Write-Host '!! A NEW ELEVATED SESSION WILL OPEN IN THIS FOLDER.     !!' -ForegroundColor Yellow
Write-Host '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!' -ForegroundColor Yellow
Write-Host "Working directory: $currentPath" -ForegroundColor Cyan
Write-Host 'Only continue if you trust this repo and need elevated access.' -ForegroundColor Red

if ($DryRun) {
    Write-Host ''
    Write-Host "DRY RUN: would open a new elevated $Shell shell here." -ForegroundColor Green
    exit 0
}

Invoke-OptionalAudioWarning

$confirm = Read-Host 'Open the elevated shell now? [y/N]'
if ($confirm -notmatch '^(y|yes)$') {
    Write-Host 'Cancelled. No elevated shell was opened.' -ForegroundColor Yellow
    exit 1
}

if (-not (Request-PrivilegedApproval -Action 'administrator shell' -Reason 'A new elevated shell is being opened from the personal-tools repo.')) {
    Write-Host 'Approval was not granted, so the shell was not opened.' -ForegroundColor Yellow
    exit 1
}

if ($Shell -eq 'cmd') {
    $commandText = "Set-Location -LiteralPath '$($currentPath.Replace("'", "''"))'; cmd.exe"
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -WorkingDirectory $currentPath -ArgumentList @('-NoExit', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $commandText) | Out-Null
    exit 0
}

$setLocationCommand = "Set-Location -LiteralPath '$($currentPath.Replace("'", "''"))'"
Start-Process -FilePath 'powershell.exe' -Verb RunAs -WorkingDirectory $currentPath -ArgumentList @('-NoExit', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $setLocationCommand) | Out-Null
