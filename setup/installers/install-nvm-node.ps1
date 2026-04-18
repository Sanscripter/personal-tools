param(
    [switch]$Status
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\core\setup-utils.ps1')

Write-Host 'NVM / Node.js / npm setup' -ForegroundColor Cyan
Refresh-NodeToolingPath

if ($Status) {
    Show-VersionIfAvailable -CommandName 'nvm' -CommandArgs @('version')
    Show-VersionIfAvailable -CommandName 'node' -CommandArgs @('-v')
    Show-VersionIfAvailable -CommandName 'npm' -CommandArgs @('-v')
    exit 0
}

$shouldContinue = Ensure-ElevatedSession -ScriptPath $PSCommandPath -Reason 'NVM for Windows may modify machine-level paths and symlinks.'
if (-not $shouldContinue) {
    exit 0
}

if (-not (Get-Command nvm -ErrorAction SilentlyContinue)) {
    Install-WindowsPackage -DisplayName 'NVM for Windows' -WingetId 'CoreyButler.NVMforWindows' -ChocoId 'nvm'
    Refresh-NodeToolingPath
}

if (-not (Get-Command nvm -ErrorAction SilentlyContinue)) {
    throw 'NVM is not available in this shell yet. Open a new terminal and run the script again.'
}

Write-Section 'Installing the latest Node.js release'
& nvm install latest
if ($LASTEXITCODE -ne 0) {
    throw 'nvm install latest failed.'
}

Write-Section 'Activating the latest Node.js release'
& nvm use latest
if ($LASTEXITCODE -ne 0) {
    throw 'nvm use latest failed.'
}

Refresh-NodeToolingPath

if (Get-Command npm -ErrorAction SilentlyContinue) {
    Write-Section 'Updating npm to the latest available version'
    & npm install -g npm@latest
    if ($LASTEXITCODE -ne 0) {
        throw 'npm update failed.'
    }
}

Show-VersionIfAvailable -CommandName 'nvm' -CommandArgs @('version')
Show-VersionIfAvailable -CommandName 'node' -CommandArgs @('-v')
Show-VersionIfAvailable -CommandName 'npm' -CommandArgs @('-v')

Write-Host ''
Write-Host 'NVM, Node.js, and npm are ready.' -ForegroundColor Green
