param(
    [ValidateSet('powershell', 'cmd')]
    [string]$Shell = 'powershell',
    [switch]$DryRun
)

$target = Join-Path $PSScriptRoot 'core\open-admin-shell.ps1'
if (-not (Test-Path $target)) {
    throw 'The admin shell helper could not be found.'
}

& $target @args
exit $LASTEXITCODE
