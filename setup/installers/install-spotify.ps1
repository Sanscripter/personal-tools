param(
    [switch]$Status,
    [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\core\setup-utils.ps1')

function Get-SpotifyInstallInfo {
    $info = [ordered]@{
        Installed = $false
        ProtocolRegistered = $false
        Running = $false
        Path = ''
        Source = ''
    }

    $candidates = @(
        (Join-Path $env:APPDATA 'Spotify\Spotify.exe'),
        (Join-Path $env:LOCALAPPDATA 'Spotify\Spotify.exe'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\Spotify.exe'),
        (Join-Path $env:ProgramFiles 'Spotify\Spotify.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Spotify\Spotify.exe')
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            $info.Installed = $true
            $info.Path = $candidate
            $info.Source = 'filesystem'
            break
        }
    }

    foreach ($regPath in @(
        'Registry::HKEY_CLASSES_ROOT\spotify\shell\open\command',
        'Registry::HKEY_CURRENT_USER\Software\Classes\spotify\shell\open\command'
    )) {
        if (Test-Path $regPath) {
            $info.ProtocolRegistered = $true

            try {
                $raw = (Get-Item $regPath).GetValue('')
                if (-not $info.Path -and $raw -match '"([^"]*Spotify[^"]*\.exe)"') {
                    $info.Path = $matches[1]
                    $info.Source = 'registry'
                }
            }
            catch {
            }
        }
    }

    try {
        $proc = Get-Process Spotify -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($proc) {
            $info.Running = $true
            $info.Installed = $true
            if (-not $info.Path -and $proc.Path) {
                $info.Path = $proc.Path
                $info.Source = 'process'
            }
        }
    }
    catch {
    }

    if ($info.ProtocolRegistered) {
        $info.Installed = $true
    }

    [pscustomobject]$info
}

function Show-SpotifyStatus {
    param([Parameter(Mandatory = $true)]$Info)

    Write-Host 'Spotify setup' -ForegroundColor Cyan
    if ($Info.Installed) {
        Write-Host 'Spotify app: ready' -ForegroundColor Green
    }
    else {
        Write-Host 'Spotify app: not detected' -ForegroundColor Yellow
    }

    Write-Host ('Protocol: ' + ($(if ($Info.ProtocolRegistered) { 'registered' } else { 'not registered' })))
    Write-Host ('Running: ' + ($(if ($Info.Running) { 'yes' } else { 'no' })))
    if ($Info.Path) {
        Write-Host ('Path: ' + $Info.Path)
    }
    else {
        Write-Host 'Path: not found yet'
    }
}

$info = Get-SpotifyInstallInfo

if ($CheckOnly) {
    if ($info.Installed) {
        exit 0
    }

    exit 1
}

if ($Status) {
    Show-SpotifyStatus -Info $info
    exit 0
}

Write-Host 'Spotify setup' -ForegroundColor Cyan

if ($info.Installed) {
    Write-Host 'Spotify is already set up on this machine.' -ForegroundColor Green
    Show-SpotifyStatus -Info $info
    exit 0
}

Write-Section 'Installing Spotify'

if (Test-Command 'winget') {
    & winget install -e --id Spotify.Spotify --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'winget did not complete cleanly. Falling back to the direct installer...' -ForegroundColor Yellow
    }
}
else {
    Write-Host 'winget is not available here. Using the direct Spotify installer...' -ForegroundColor Yellow
}

$info = Get-SpotifyInstallInfo
if (-not $info.Installed) {
    $installer = Join-Path $env:TEMP 'SpotifySetup.exe'
    Write-Host 'Downloading Spotify installer...' -ForegroundColor Cyan
    Invoke-WebRequest -UseBasicParsing 'https://download.scdn.co/SpotifySetup.exe' -OutFile $installer

    Write-Host 'Running Spotify installer...' -ForegroundColor Cyan
    $installProcess = Start-Process -FilePath $installer -ArgumentList '/silent' -Wait -PassThru -ErrorAction SilentlyContinue

    if (-not $installProcess -or $installProcess.ExitCode -ne 0) {
        Write-Host 'Silent install did not report success. Launching the standard installer flow...' -ForegroundColor Yellow
        Start-Process -FilePath $installer
    }
}

$info = Get-SpotifyInstallInfo
if (-not $info.Installed) {
    throw 'Spotify was not detected after setup. Open Spotify once after the installer finishes and then retry your command.'
}

Write-Host ''
Write-Host 'Spotify is ready.' -ForegroundColor Green
Show-SpotifyStatus -Info $info
exit 0
