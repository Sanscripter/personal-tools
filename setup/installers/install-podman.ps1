param(
    [switch]$Status
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\core\setup-utils.ps1')

Write-Host 'Podman setup (open-source Docker alternative)' -ForegroundColor Cyan
Refresh-NodeToolingPath

if ($Status) {
    Show-VersionIfAvailable -CommandName 'podman' -CommandArgs @('--version')
    exit 0
}

$shouldContinue = Ensure-ElevatedSession -ScriptPath $PSCommandPath -Reason 'Podman installation can write to Program Files and machine-wide settings.'
if (-not $shouldContinue) {
    exit 0
}

if (-not (Get-Command podman -ErrorAction SilentlyContinue)) {
    Install-WindowsPackage -DisplayName 'Podman Desktop' -WingetId 'RedHat.Podman-Desktop' -ChocoId 'podman-desktop' -AltChocoId 'podman'
}

Show-VersionIfAvailable -CommandName 'podman' -CommandArgs @('--version')

Write-Host ''
Write-Host 'Podman setup finished. On first use, you may want to run: podman machine init' -ForegroundColor Green
