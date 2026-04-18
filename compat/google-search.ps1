[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $InputArgs
)

$target = Join-Path $PSScriptRoot '..\scripts\web\google-search.ps1'
if (-not (Test-Path $target)) {
    throw 'The Google search helper could not be found.'
}

& $target @InputArgs
exit $LASTEXITCODE
