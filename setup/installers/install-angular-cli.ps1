param(
    [switch]$Status
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\core\setup-utils.ps1')

Write-Host 'Angular CLI setup' -ForegroundColor Cyan
Refresh-NodeToolingPath

if ($Status) {
    Show-VersionIfAvailable -CommandName 'node' -CommandArgs @('-v')
    Show-VersionIfAvailable -CommandName 'npm' -CommandArgs @('-v')

    if (Get-Command ng -ErrorAction SilentlyContinue) {
        Write-Host ''
        Write-Host 'Angular CLI version confirmation:' -ForegroundColor Green
        & ng version
    }
    else {
        Write-Host ''
        Write-Host 'Angular CLI is not on PATH yet.' -ForegroundColor Yellow
    }

    exit 0
}

if (-not (Get-Command node -ErrorAction SilentlyContinue) -or -not (Get-Command npm -ErrorAction SilentlyContinue)) {
    throw 'Node.js and npm are required first. Run install-nvm-node.bat or tools-setup.bat all.'
}

Add-PathIfExists (Join-Path $env:AppData 'npm')
Write-Section 'Installing Angular CLI globally'
& npm install -g @angular/cli@latest
if ($LASTEXITCODE -ne 0) {
    throw 'Angular CLI installation failed.'
}

Add-PathIfExists (Join-Path $env:AppData 'npm')

if (-not (Get-Command ng -ErrorAction SilentlyContinue)) {
    throw 'Angular CLI was installed but ng is not available in this shell yet. Open a new terminal and run ng version.'
}

Write-Host ''
Write-Host 'Angular CLI version confirmation:' -ForegroundColor Green
& ng version

Write-Host ''
Write-Host 'Angular CLI is ready.' -ForegroundColor Green
