param(
    [switch]$Status
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\core\setup-utils.ps1')

function Update-PythonPath {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Python'),
        'C:\Python314',
        'C:\Python313',
        'C:\Python312',
        'C:\Python311',
        'C:\Python310'
    )

    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }

        Add-PathIfExists $candidate
        Add-PathIfExists (Join-Path $candidate 'Scripts')

        if (Test-Path $candidate) {
            Get-ChildItem -Path $candidate -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                Add-PathIfExists $_.FullName
                Add-PathIfExists (Join-Path $_.FullName 'Scripts')
            }
        }
    }

    Add-PathIfExists (Join-Path $env:ProgramData 'chocolatey\bin')
}

function Show-PythonInfo {
    Update-PythonPath
    Show-VersionIfAvailable -CommandName 'python' -CommandArgs @('--version')
    Show-VersionIfAvailable -CommandName 'py' -CommandArgs @('-3', '--version')

    if (Get-Command python -ErrorAction SilentlyContinue) {
        Write-Host ''
        Write-Host 'pip version:' -ForegroundColor Green
        & python -m pip --version
    }
    else {
        Show-VersionIfAvailable -CommandName 'pip' -CommandArgs @('--version')
    }
}

Write-Host 'Python setup' -ForegroundColor Cyan
Update-PythonPath

if ($Status) {
    Show-PythonInfo
    exit 0
}

if (-not (Get-Command python -ErrorAction SilentlyContinue) -and -not (Get-Command py -ErrorAction SilentlyContinue)) {
    $shouldContinue = Ensure-ElevatedSession -ScriptPath $PSCommandPath -Reason 'Python installation may need Administrator access depending on the package source.'
    if (-not $shouldContinue) {
        exit 0
    }

    Install-WindowsPackage -DisplayName 'Python 3' -WingetId 'Python.Python.3.12' -ChocoId 'python'
    Update-PythonPath
}

if (Get-Command python -ErrorAction SilentlyContinue) {
    Write-Section 'Ensuring pip is available'
    & python -m ensurepip --upgrade
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'pip bootstrap did not complete cleanly, but Python may still already include pip.' -ForegroundColor DarkYellow
    }

    Update-PythonPath
}

Show-PythonInfo

Write-Host ''
Write-Host 'Python setup finished. Use: python --version' -ForegroundColor Green
