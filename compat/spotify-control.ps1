param()
$target = Join-Path $PSScriptRoot '..\scripts\media\spotify-control.ps1'
if (-not (Test-Path $target)) {
    throw 'The Spotify control helper could not be found.'
}

& $target @args
exit $LASTEXITCODE
