param(
    [string]$Action = 'manual approval check',
    [string]$Reason = 'A manual approval challenge was requested from the personal-tools repo.',
    [int]$TimeoutSec = 0,
    [switch]$DryRun,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$InputArgs
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot '..\..\setup\core\setup-utils.ps1')

if ($InputArgs -and $InputArgs.Count -gt 0) {
    $Action = ($InputArgs -join ' ').Trim()
}

Write-Host ''
Write-Host '== OTP approval ==' -ForegroundColor Cyan
Write-Host ("Action: {0}" -f $Action)

if ($DryRun) {
    Write-Host 'DRY RUN: the approval challenge was not sent.' -ForegroundColor Green
    Write-Host ("Mode: {0}" -f (Get-ApprovalMode)) -ForegroundColor Cyan
    Write-Host ("Page: {0}" -f (Get-ApprovalPageUrl)) -ForegroundColor Cyan
    exit 0
}

$result = if ($TimeoutSec -gt 0) {
    Request-PrivilegedApproval -Action $Action -Reason $Reason -TimeoutSec $TimeoutSec
}
else {
    Request-PrivilegedApproval -Action $Action -Reason $Reason
}

if ($result) {
    exit 0
}

exit 1
