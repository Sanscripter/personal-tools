[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $InputArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Show-Help {
    @"
YouTube helper

Usage:
  youtube open
  youtube home
  youtube search <query>
  youtube play
  youtube play <query>
  youtube pause
  youtube toggle
  youtube next
  youtube previous
  youtube watch <url|video id>
  youtube playlist <url|playlist id>
  youtube music
  youtube help

What it does:
  - opens YouTube in Google Chrome
  - lets Chrome handle web playback instead of requiring an app
  - uses the Windows global media session for play, pause, next, and previous
"@ | Write-Host
}

function Get-RawInput {
    if ($InputArgs -and $InputArgs.Count -gt 0) {
        return ($InputArgs -join ' ').Trim()
    }

    $raw = [Environment]::GetEnvironmentVariable('YOUTUBE_RAW_ARGS', 'Process')
    if ($null -eq $raw) {
        return ''
    }

    return $raw.Trim()
}

function Open-InChrome {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Target
    )

    $chromeLauncher = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\bin\chrome.bat'))

    if (Test-Path $chromeLauncher) {
        $env:CHROME_TARGET = $Target
        try {
            $process = Start-Process -FilePath $chromeLauncher -ArgumentList @('open') -PassThru -Wait
            exit $process.ExitCode
        }
        finally {
            Remove-Item Env:CHROME_TARGET -ErrorAction SilentlyContinue
        }
    }

    Start-Process $Target | Out-Null
    exit 0
}

function Invoke-MediaAction {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('status','play','pause','toggle','next','previous')]
        [string] $Action
    )

    $mediaScript = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\media\media-control.ps1'))
    & powershell -NoProfile -ExecutionPolicy Bypass -File $mediaScript -Action $Action
    exit $LASTEXITCODE
}

function Resolve-WatchUrl {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Value
    )

    $trimmed = $Value.Trim()
    if ($trimmed -match '^https?://') {
        return $trimmed
    }

    return "https://www.youtube.com/watch?v=$trimmed"
}

function Resolve-PlaylistUrl {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Value
    )

    $trimmed = $Value.Trim()
    if ($trimmed -match '^https?://') {
        return $trimmed
    }

    return "https://www.youtube.com/playlist?list=$trimmed"
}

$rawInput = Get-RawInput

if ([string]::IsNullOrWhiteSpace($rawInput)) {
    Show-Help
    exit 0
}

if ($rawInput -match '^(?i)(help|/h|-h|--help|\?)$') {
    Show-Help
    exit 0
}

if ($rawInput -match '^(?i)(open|home|launch)$') {
    Open-InChrome -Target 'https://www.youtube.com/'
}

if ($rawInput -match '^(?i)(music)$') {
    Open-InChrome -Target 'https://music.youtube.com/'
}

if ($rawInput -match '^(?i)(status)$') {
    Invoke-MediaAction -Action 'status'
}

if ($rawInput -match '^(?i)(pause)$') {
    Invoke-MediaAction -Action 'pause'
}

if ($rawInput -match '^(?i)(toggle|playpause)$') {
    Invoke-MediaAction -Action 'toggle'
}

if ($rawInput -match '^(?i)(next|skip)$') {
    Invoke-MediaAction -Action 'next'
}

if ($rawInput -match '^(?i)(previous|prev|back)$') {
    Invoke-MediaAction -Action 'previous'
}

if ($rawInput -match '^(?i)(play)\s*$') {
    Invoke-MediaAction -Action 'play'
}

if ($rawInput -match '^(?i)(search|find)\s+(.+)$') {
    $query = [System.Uri]::EscapeDataString($Matches[2].Trim())
    Open-InChrome -Target "https://www.youtube.com/results?search_query=$query"
}

if ($rawInput -match '^(?i)(play)\s+(.+)$') {
    $query = [System.Uri]::EscapeDataString($Matches[2].Trim())
    Open-InChrome -Target "https://www.youtube.com/results?search_query=$query"
}

if ($rawInput -match '^(?i)(watch|video)\s+(.+)$') {
    Open-InChrome -Target (Resolve-WatchUrl -Value $Matches[2])
}

if ($rawInput -match '^(?i)(playlist|list)\s+(.+)$') {
    Open-InChrome -Target (Resolve-PlaylistUrl -Value $Matches[2])
}

if ($rawInput -match '^https?://') {
    Open-InChrome -Target $rawInput
}

$query = [System.Uri]::EscapeDataString($rawInput)
Open-InChrome -Target "https://www.youtube.com/results?search_query=$query"
