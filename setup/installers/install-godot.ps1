param(
    [switch]$Status
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\core\setup-utils.ps1')

Write-Host 'Godot setup' -ForegroundColor Cyan
Refresh-NodeToolingPath

if ($Status) {
    Show-VersionIfAvailable -CommandName 'godot' -CommandArgs @('--version')
    exit 0
}

$shouldContinue = Ensure-ElevatedSession -ScriptPath $PSCommandPath -Reason 'Godot installation may need Administrator approval for machine-wide setup.'
if (-not $shouldContinue) {
    exit 0
}

if (-not (Get-Command godot -ErrorAction SilentlyContinue)) {
    Install-WindowsPackage -DisplayName 'Godot Engine' -WingetId 'GodotEngine.GodotEngine' -ChocoId 'godot'
}

Show-VersionIfAvailable -CommandName 'godot' -CommandArgs @('--version')

Write-Host ''
Write-Host 'Godot setup finished.' -ForegroundColor Green
