param(
    [ValidateSet('powershell', 'cmd')]
    [string]$Shell = 'powershell',
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Invoke-OptionalAudioWarning {
    $audioChoice = Read-Host 'Play an audible warning before requesting Administrator mode? [y/N]'
    if ($audioChoice -notmatch '^(y|yes)$') {
        return
    }

    try {
        [console]::Beep(1200, 150)
        Start-Sleep -Milliseconds 100
        [console]::Beep(900, 250)
    }
    catch {
        Write-Host 'Audio warning is not available in this host.' -ForegroundColor DarkYellow
    }
}

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

if ($Shell -eq 'cmd') {
    $commandText = "Set-Location -LiteralPath '$($currentPath.Replace("'", "''"))'; cmd.exe"
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -WorkingDirectory $currentPath -ArgumentList @('-NoExit', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $commandText) | Out-Null
    exit 0
}

$setLocationCommand = "Set-Location -LiteralPath '$($currentPath.Replace("'", "''"))'"
Start-Process -FilePath 'powershell.exe' -Verb RunAs -WorkingDirectory $currentPath -ArgumentList @('-NoExit', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $setLocationCommand) | Out-Null
