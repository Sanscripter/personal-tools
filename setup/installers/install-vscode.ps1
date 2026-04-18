param(
    [switch]$Status
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\core\setup-utils.ps1')

function Update-VSCodePath {
    $x86ProgramFiles = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')

    Add-PathIfExists (Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\bin')
    Add-PathIfExists (Join-Path $env:ProgramFiles 'Microsoft VS Code\bin')

    if ($x86ProgramFiles) {
        Add-PathIfExists (Join-Path $x86ProgramFiles 'Microsoft VS Code\bin')
    }
}

function Show-VSCodeInfo {
    $codeCommand = Get-Command code -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($codeCommand) {
        Write-Host ''
        Write-Host 'code launcher: ready' -ForegroundColor Green
        Write-Host ('Path: ' + $codeCommand.Source)
    }
    else {
        Write-Host ''
        Write-Host 'code is not on PATH yet. Open a new terminal after installation if needed.' -ForegroundColor Yellow
    }
}

Write-Host 'VS Code setup' -ForegroundColor Cyan
Update-VSCodePath

if ($Status) {
    Show-VSCodeInfo
    exit 0
}

if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    Install-WindowsPackage -DisplayName 'Visual Studio Code' -WingetId 'Microsoft.VisualStudioCode' -ChocoId 'vscode'
    Update-VSCodePath
}

Show-VSCodeInfo

Write-Host ''
Write-Host 'VS Code setup finished. Use: code .' -ForegroundColor Green
